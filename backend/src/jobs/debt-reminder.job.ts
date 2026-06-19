import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { SharedExpenseParticipant } from '../modules/shared-groups/entities/shared-expense-participant.entity';
import { SharedExpense, SharedExpenseStatus } from '../modules/shared-groups/entities/shared-expense.entity';
import { SharedGroupMember, SharedGroupMemberStatus } from '../modules/shared-groups/entities/shared-group-member.entity';
import { UserNotificationPreferences } from '../modules/users/user-notification-preferences.entity';
import { User } from '../modules/users/user.entity';
import { PushNotificationService } from '../common/services/push-notification.service';
import { SharedGroup } from '../modules/shared-groups/entities/shared-group.entity';
import { SharedSettlement } from '../modules/shared-groups/entities/shared-settlement.entity';

@Injectable()
export class DebtReminderJob {
  private readonly logger = new Logger(DebtReminderJob.name);

  constructor(
    @InjectRepository(SharedExpenseParticipant)
    private participantRepo: Repository<SharedExpenseParticipant>,
    @InjectRepository(SharedExpense)
    private expenseRepo: Repository<SharedExpense>,
    @InjectRepository(SharedGroupMember)
    private memberRepo: Repository<SharedGroupMember>,
    @InjectRepository(SharedSettlement)
    private settlementRepo: Repository<SharedSettlement>,
    @InjectRepository(UserNotificationPreferences)
    private prefsRepo: Repository<UserNotificationPreferences>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(SharedGroup)
    private groupRepo: Repository<SharedGroup>,
    private pushService: PushNotificationService,
  ) {}

  /** Runs daily at 10:00 AM */
  @Cron('0 10 * * *')
  async run(): Promise<void> {
    this.logger.log('Running DebtReminderJob...');

    // Load all active users who have debt_reminder_days NOT null
    const prefs = await this.prefsRepo
      .createQueryBuilder('p')
      .where('p.debtReminderDays IS NOT NULL')
      .getMany();

    if (prefs.length === 0) return;

    const now = new Date();

    for (const pref of prefs) {
      try {
        const user = await this.userRepo.findOne({
          where: { id: pref.userId },
          select: ['id', 'fullName', 'fcmToken'],
        });
        if (!user?.fcmToken) continue;

        const reminderDays = pref.debtReminderDays!;

        // Get all groups where user is an active member
        const memberships = await this.memberRepo.find({
          where: { userId: pref.userId, status: SharedGroupMemberStatus.ACTIVE },
        });
        if (memberships.length === 0) continue;

        // For each group, calculate how much this user owes
        let totalOwed = 0;
        const groupDebts: Array<{ groupName: string; amount: number; oldestDate: Date }> = [];

        for (const membership of memberships) {
          const groupId = membership.groupId;

          // Load approved expenses where this user is a participant (not payer)
          const participations = await this.participantRepo
            .createQueryBuilder('p')
            .innerJoinAndSelect('p.expense', 'e')
            .where('p.userId = :userId', { userId: pref.userId })
            .andWhere('e.groupId = :groupId', { groupId })
            .andWhere('e.status = :status', { status: SharedExpenseStatus.APPROVED })
            .andWhere('p.isSettled = false')
            .andWhere('e.payerId != :userId', { userId: pref.userId })
            .getMany();

          if (participations.length === 0) continue;

          // Filter by age (only if the oldest unsettled expense is >= reminderDays old)
          const oldestDate = participations.reduce((oldest, p) => {
            const d = p.expense.date instanceof Date ? p.expense.date : new Date(p.expense.date);
            return d < oldest ? d : oldest;
          }, new Date());

          const ageInDays = Math.floor(
            (now.getTime() - oldestDate.getTime()) / (1000 * 60 * 60 * 24),
          );
          if (ageInDays < reminderDays) continue;

          // Apply settlements
          const settlements = await this.settlementRepo.find({ where: { groupId, payerId: pref.userId } });
          const settledTotal = settlements.reduce((s, t) => s + Number(t.amount), 0);
          const rawOwed = participations.reduce((s, p) => s + Number(p.shareAmount), 0);
          const netOwed = Math.max(0, rawOwed - settledTotal);

          if (netOwed > 0.01) {
            const group = await this.groupRepo.findOne({ where: { id: groupId }, select: ['name'] });
            groupDebts.push({ groupName: group?.name ?? groupId, amount: netOwed, oldestDate });
            totalOwed += netOwed;
          }
        }

        if (totalOwed < 0.01 || groupDebts.length === 0) continue;

        const topGroup = groupDebts.sort((a, b) => b.amount - a.amount)[0];

        await this.pushService.send({
          userId: user.id,
          fcmToken: user.fcmToken,
          title: 'Recordatorio de deuda',
          body: `Tienes L ${totalOwed.toFixed(2)} pendientes en ${groupDebts.length === 1 ? topGroup.groupName : `${groupDebts.length} grupos`}`,
          data: { type: 'debt_reminder' },
          skipDailyCap: false,
        }).catch(() => {/* Non-fatal */});

        this.logger.log(`Sent debt reminder to user ${pref.userId}: L ${totalOwed.toFixed(2)}`);
      } catch (err) {
        this.logger.error(`DebtReminderJob error for user ${pref.userId}: ${err}`);
      }
    }
  }
}
