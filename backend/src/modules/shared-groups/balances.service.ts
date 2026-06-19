import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SharedExpense } from './entities/shared-expense.entity';
import { SharedExpenseParticipant } from './entities/shared-expense-participant.entity';
import { SharedSettlement } from './entities/shared-settlement.entity';
import { SharedGroupMemberStatus } from './entities/shared-group-member.entity';
import { SharedGroupsService } from './shared-groups.service';

export interface BalanceEntry {
  fromUserId: string;
  fromUserName: string;
  toUserId: string;
  toUserName: string;
  amount: number;
}

export interface GroupBalanceSummary {
  balances: BalanceEntry[];
  youAreOwed: number;
  youOwe: number;
}

export interface WidgetSummary {
  totalOwed: number;
  totalDue: number;
  hasGroups: boolean;
}

@Injectable()
export class BalancesService {
  constructor(
    @InjectRepository(SharedExpense)
    private expenseRepo: Repository<SharedExpense>,
    @InjectRepository(SharedExpenseParticipant)
    private participantRepo: Repository<SharedExpenseParticipant>,
    @InjectRepository(SharedSettlement)
    private settlementRepo: Repository<SharedSettlement>,
    private groupsService: SharedGroupsService,
  ) {}

  /**
   * Calculates the simplified balance matrix for a group.
   *
   * Algorithm:
   *  1. Build raw balance map: for each participant, they OWE the payer their share_amount
   *  2. Reduce to net amounts between each pair
   *  3. Subtract settled amounts from settlements
   *  4. Return only positive-net debts
   */
  async getGroupBalances(
    currentUserId: string,
    groupId: string,
  ): Promise<GroupBalanceSummary> {
    await this.groupsService.assertActiveMember(currentUserId, groupId);

    // Load all expenses + participants for the group
    const expenses = await this.expenseRepo.find({
      where: { groupId },
      relations: ['payer', 'participants', 'participants.user'],
    });

    // net[debtorId][creditorId] = amount debtor owes creditor
    const net: Record<string, Record<string, number>> = {};
    const names: Record<string, string> = {};

    const ensureEntry = (a: string, b: string) => {
      net[a] = net[a] ?? {};
      net[a][b] = net[a][b] ?? 0;
    };

    for (const expense of expenses) {
      const payerId = expense.payerId;
      names[payerId] = expense.payer?.fullName ?? payerId;

      for (const p of expense.participants) {
        const participantId = p.userId;
        names[participantId] = p.user?.fullName ?? participantId;

        if (participantId === payerId) continue; // payer doesn't owe themselves

        // participant owes payer their share
        ensureEntry(participantId, payerId);
        net[participantId][payerId] += Number(p.shareAmount);
      }
    }

    // Apply settlements — reduce debts
    const settlements = await this.settlementRepo.find({ where: { groupId } });
    for (const s of settlements) {
      // The payer in the settlement is paying off a debt to the receiver
      const from = s.payerId;
      const to = s.receiverId;
      const amount = Number(s.amount);

      // Reduce from→to debt
      if (net[from]?.[to]) {
        net[from][to] = Math.max(0, net[from][to] - amount);
      }
      // Increase to→from (if settlement overpays in edge case — extremely rare)
    }

    // Build result — net out bilateral debts
    const balances: BalanceEntry[] = [];
    const processed = new Set<string>();

    for (const [from, targets] of Object.entries(net)) {
      for (const [to, amount] of Object.entries(targets)) {
        const key = [from, to].sort().join('|');
        if (processed.has(key)) continue;
        processed.add(key);

        const fwd = net[from]?.[to] ?? 0;
        const rev = net[to]?.[from] ?? 0;
        const netAmount = fwd - rev;

        if (netAmount > 0.005) {
          balances.push({
            fromUserId: from,
            fromUserName: names[from] ?? from,
            toUserId: to,
            toUserName: names[to] ?? to,
            amount: Math.round(netAmount * 100) / 100,
          });
        } else if (netAmount < -0.005) {
          balances.push({
            fromUserId: to,
            fromUserName: names[to] ?? to,
            toUserId: from,
            toUserName: names[from] ?? from,
            amount: Math.round(-netAmount * 100) / 100,
          });
        }
      }
    }

    // Compute user-specific summary
    const youAreOwed = balances
      .filter((b) => b.toUserId === currentUserId)
      .reduce((acc, b) => acc + b.amount, 0);
    const youOwe = balances
      .filter((b) => b.fromUserId === currentUserId)
      .reduce((acc, b) => acc + b.amount, 0);

    return { balances, youAreOwed, youOwe };
  }

  /**
   * Aggregate summary across ALL groups — used for the Home Screen widget card.
   */
  async getWidgetSummary(userId: string): Promise<WidgetSummary> {
    // Get all group IDs where user is an active member
    const memberships = await this.groupsService['memberRepo'].find({
      where: { userId, status: SharedGroupMemberStatus.ACTIVE },
      select: ['groupId'],
    });

    if (memberships.length === 0) {
      return { totalOwed: 0, totalDue: 0, hasGroups: false };
    }

    let totalOwed = 0;
    let totalDue = 0;

    for (const m of memberships) {
      const summary = await this.getGroupBalances(userId, m.groupId);
      totalOwed += summary.youAreOwed;
      totalDue += summary.youOwe;
    }

    return {
      totalOwed: Math.round(totalOwed * 100) / 100,
      totalDue: Math.round(totalDue * 100) / 100,
      hasGroups: true,
    };
  }
}
