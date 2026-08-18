import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { SharedExpense, RecurringInterval, SharedExpensePaymentMethod, SharedExpenseStatus } from './entities/shared-expense.entity';
import { SharedExpenseParticipant } from './entities/shared-expense-participant.entity';
import { SharedGroupSettings } from './entities/shared-group-settings.entity';
import { SharedExpenseApproval, ApprovalStatus } from './entities/shared-expense-approval.entity';
import { CreateSharedExpenseDto, UpdateSharedExpenseDto, UpdateGroupSettingsDto } from './shared-groups.dto';
import { SharedGroupsService } from './shared-groups.service';
import { CashService } from '../cash/cash.service';
import { PushNotificationService } from '../../common/services/push-notification.service';
import { SharedGroupMember, SharedGroupMemberStatus } from './entities/shared-group-member.entity';
import { SharedGroup } from './entities/shared-group.entity';
import { User } from '../users/user.entity';
import { UserNotificationPreferences } from '../users/user-notification-preferences.entity';
import { Insight, InsightPriority, InsightType } from '../insights/insight.entity';
import { formatMoney } from '../../common/utils/money-format.util';

@Injectable()
export class SharedExpensesService {
  constructor(
    @InjectRepository(SharedExpense)
    private expenseRepo: Repository<SharedExpense>,
    @InjectRepository(SharedExpenseParticipant)
    private participantRepo: Repository<SharedExpenseParticipant>,
    @InjectRepository(SharedGroupMember)
    private memberRepo: Repository<SharedGroupMember>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(SharedGroup)
    private groupRepo: Repository<SharedGroup>,
    @InjectRepository(SharedGroupSettings)
    private settingsRepo: Repository<SharedGroupSettings>,
    @InjectRepository(SharedExpenseApproval)
    private approvalRepo: Repository<SharedExpenseApproval>,
    @InjectRepository(UserNotificationPreferences)
    private prefsRepo: Repository<UserNotificationPreferences>,
    @InjectRepository(Insight)
    private insightRepo: Repository<Insight>,
    private groupsService: SharedGroupsService,
    private cashService: CashService,
    private pushService: PushNotificationService,
    private dataSource: DataSource,
  ) {}

  /**
   * Creates a shared expense.
   *
   * Accounting rules:
   *  - NO insert into `expenses` table (zero contamination of personal reports)
   *  - IF payer is the current user AND method = cash AND cashAccountId is provided:
   *      record a CashTransaction WITHDRAW for the TOTAL amount (real money that left)
   *  - Balance tracking happens via shared_expense_participants (runtime calculation)
   */
  async createSharedExpense(
    currentUserId: string,
    groupId: string,
    dto: CreateSharedExpenseDto,
  ): Promise<SharedExpense> {
    // 1. Verify caller is an active member
    await this.groupsService.assertActiveMember(currentUserId, groupId);

    // 2. Verify payer is an active member
    await this.groupsService.assertActiveMember(dto.payerId, groupId);

    // 3. Validate all participants are active members
    for (const p of dto.participants) {
      await this.groupsService.assertActiveMember(p.userId, groupId);
    }

    // 4. Validate Σ share_amounts == total_amount ±0.01
    const sum = dto.participants.reduce((acc, p) => acc + Number(p.shareAmount), 0);
    if (Math.abs(sum - Number(dto.totalAmount)) > 0.01) {
      throw new BadRequestException(
        `Sum of shares (${sum}) does not match total amount (${dto.totalAmount})`,
      );
    }

    // 5. Persist shared expense
    const settings = await this.settingsRepo.findOne({ where: { groupId } });
    const requiresApproval = settings?.requiresApproval ?? false;

    const expense = this.expenseRepo.create({
      groupId,
      payerId: dto.payerId,
      totalAmount: dto.totalAmount,
      currency: 'HNL',
      description: dto.description,
      categoryLabel: dto.categoryLabel,
      paymentMethod: dto.paymentMethod ?? SharedExpensePaymentMethod.CASH,
      note: dto.note,
      date: new Date(dto.date),
      receiptUrl: dto.receiptUrl ?? null,
      isRecurring: dto.isRecurring ?? false,
      recurringInterval: dto.recurringInterval ?? null,
      recurringDay: dto.recurringDay ?? null,
      status: requiresApproval ? SharedExpenseStatus.PENDING : SharedExpenseStatus.APPROVED,
      nextRecurrenceAt: dto.isRecurring
        ? this._calcNextRecurrence(dto.date, dto.recurringInterval, dto.recurringDay)
        : null,
    });
    const saved = await this.expenseRepo.save(expense);

    // 6. Persist participants
    const participants = dto.participants.map((p) =>
      this.participantRepo.create({
        expenseId: saved.id,
        userId: p.userId,
        shareAmount: p.shareAmount,
      }),
    );
    await this.participantRepo.save(participants);

    // 7. Cash impact — only if:
    //    - current user is the payer
    //    - payment method is cash
    //    - a cash account ID was provided
    const isCashPayer =
      dto.payerId === currentUserId &&
      (dto.paymentMethod ?? SharedExpensePaymentMethod.CASH) === SharedExpensePaymentMethod.CASH &&
      dto.cashAccountId;

    if (isCashPayer) {
      try {
        await this.cashService.withdraw(currentUserId, dto.cashAccountId!, {
          amount: Number(dto.totalAmount),
          description: `[Compartido] ${dto.description}`,
          date: dto.date,
        });
      } catch {
        // Insufficient balance is non-fatal — proceed without blocking expense creation
      }
    }

    // 8. Push notifications to other participants
    const participantUserIds = dto.participants
      .map((p) => p.userId)
      .filter((id) => id !== currentUserId);

    if (participantUserIds.length > 0) {
      const [payer, group] = await Promise.all([
        this.userRepo.findOne({ where: { id: currentUserId }, select: ['id', 'fullName'] }),
        this.groupRepo.findOne({ where: { id: groupId }, select: ['id', 'name'] }),
      ]);
      const payerName = payer?.fullName ?? 'Alguien';
      const groupName = group?.name ?? 'grupo compartido';

      const shareByUserId = new Map(
        dto.participants.map((p) => [p.userId, Number(p.shareAmount)]),
      );

      const users = await this.userRepo.find({
        where: participantUserIds.map((id) => ({ id })),
        select: ['id', 'fullName', 'fcmToken'],
      });
      const preferences = await this.prefsRepo.find({
        where: participantUserIds.map((userId) => ({ userId })),
      });
      const pushEnabled = new Map(
        preferences.map((preference) => [
          preference.userId,
          preference.pushSharedExpenseChanges,
        ]),
      );
      for (const user of users) {
        if (!user.fcmToken || pushEnabled.get(user.id) === false) continue;
        const myShare = shareByUserId.get(user.id) ?? Number(dto.totalAmount);
        await this.pushService.send({
          userId: user.id,
          fcmToken: user.fcmToken,
          title: `Nuevo gasto en ${groupName}`,
          body: `${payerName} agregó "${dto.description}" — tu parte: L ${formatMoney(myShare, 2)}`,
          data: { type: 'shared_expense', groupId, expenseId: saved.id },
          skipDailyCap: true,
        }).catch(() => {/* Non-fatal */});
      }

      // Persist an in-app notification as well, so the event is visible even
      // when the browser has no FCM permission or the user is offline.
      const notificationBody = `${payerName} agregó "${dto.description}" en ${groupName} por L ${formatMoney(Number(dto.totalAmount), 2)}.`;
      await this.insightRepo.save(
        participantUserIds.map((userId) =>
          this.insightRepo.create({
            userId,
            type: InsightType.PATTERN,
            priority: InsightPriority.MEDIUM,
            title: 'Nuevo gasto compartido',
            body: notificationBody,
            metadata: {
              notificationType: 'shared_expense_created',
              groupId,
              expenseId: saved.id,
              payerId: currentUserId,
            },
            isRead: false,
            isDismissed: false,
          }),
        ),
      );
    }

    const created = await this.expenseRepo.findOne({
      where: { id: saved.id },
      relations: ['payer', 'participants', 'participants.user'],
    });
    return created!;
  }

  async getGroupExpenses(userId: string, groupId: string): Promise<SharedExpense[]> {
    await this.groupsService.assertActiveMember(userId, groupId);
    return this.expenseRepo.find({
      where: { groupId },
      relations: ['payer', 'participants', 'participants.user'],
      order: { date: 'DESC', createdAt: 'DESC' },
    });
  }

  async updateSharedExpense(
    currentUserId: string,
    groupId: string,
    expenseId: string,
    dto: UpdateSharedExpenseDto,
  ): Promise<SharedExpense> {
    await this.groupsService.assertActiveMember(currentUserId, groupId);

    const expense = await this.expenseRepo.findOne({
      where: { id: expenseId, groupId },
      relations: ['participants', 'participants.user'],
    });
    if (!expense) throw new NotFoundException('Gasto no encontrado');
    if (expense.payerId !== currentUserId) {
      throw new ForbiddenException('Solo el pagador puede editar este gasto');
    }

    // Collect participant IDs BEFORE update (for push notifications later)
    const oldParticipantIds = expense.participants.map((p) => p.userId);

    // B2 fix: wrap participant replace in a transaction to ensure atomicity
    if (dto.participants) {
      const total = dto.totalAmount ?? Number(expense.totalAmount);
      const sum = dto.participants.reduce((acc, p) => acc + Number(p.shareAmount), 0);
      if (Math.abs(sum - total) > 0.01) {
        throw new BadRequestException(
          `La suma de partes (${sum}) no coincide con el total (${total})`,
        );
      }
      await this.dataSource.transaction(async (manager) => {
        await manager.delete(SharedExpenseParticipant, { expenseId });
        await manager.save(
          SharedExpenseParticipant,
          dto.participants!.map((p) =>
            manager.create(SharedExpenseParticipant, {
              expenseId,
              userId: p.userId,
              shareAmount: p.shareAmount,
            }),
          ),
        );
      });
    }

    await this.expenseRepo.update(expenseId, {
      ...(dto.totalAmount !== undefined && { totalAmount: dto.totalAmount }),
      ...(dto.description !== undefined && { description: dto.description }),
      ...(dto.date !== undefined && { date: new Date(dto.date) }),
      ...(dto.paymentMethod !== undefined && { paymentMethod: dto.paymentMethod }),
      ...(dto.categoryLabel !== undefined && { categoryLabel: dto.categoryLabel }),
      ...(dto.note !== undefined && { note: dto.note }),
      ...(dto.receiptUrl !== undefined && { receiptUrl: dto.receiptUrl }),
      ...(dto.isRecurring !== undefined && { isRecurring: dto.isRecurring }),
      ...(dto.recurringInterval !== undefined && { recurringInterval: dto.recurringInterval }),
      ...(dto.recurringDay !== undefined && { recurringDay: dto.recurringDay }),
    });

    // Push notification to other participants about the edit
    await this._notifyExpenseChanged(
      currentUserId,
      groupId,
      expenseId,
      oldParticipantIds,
      'edit',
      dto.description ?? expense.description,
    );

    return (await this.expenseRepo.findOne({
      where: { id: expenseId },
      relations: ['payer', 'participants', 'participants.user'],
    }))!;
  }

  async deleteSharedExpense(
    currentUserId: string,
    groupId: string,
    expenseId: string,
  ): Promise<void> {
    await this.groupsService.assertActiveMember(currentUserId, groupId);

    const expense = await this.expenseRepo.findOne({
      where: { id: expenseId, groupId },
      relations: ['participants'],
    });
    if (!expense) throw new NotFoundException('Gasto no encontrado');
    if (expense.payerId !== currentUserId) {
      throw new ForbiddenException('Solo el pagador puede eliminar este gasto');
    }

    const participantIds = expense.participants.map((p) => p.userId);

    // B3 fix: delete participants first to satisfy FK constraint, then expense
    await this.participantRepo.delete({ expenseId });
    await this.expenseRepo.delete(expenseId);

    // Send push to other participants about the deletion
    await this._notifyExpenseChanged(
      currentUserId,
      groupId,
      expenseId,
      participantIds,
      'delete',
      expense.description,
    );
  }

  /**
   * Returns all shared expenses across every group where the current user is
   * an active participant, formatted for display in the personal expense list.
   * Amount returned is the user's own share, not the group total.
   */
  async getMySharedExpenses(userId: string): Promise<Array<{
    id: string;
    description: string;
    amount: number;
    totalAmount: number;
    currency: string;
    date: string;
    groupId: string;
    groupName: string;
    payerName: string;
    isPayer: boolean;
    categoryLabel: string | null;
  }>> {
    // Query from the participant side — avoids TypeORM conditional LEFT JOIN bug
    const participations = await this.participantRepo
      .createQueryBuilder('p')
      .innerJoinAndSelect('p.expense', 'e')
      .innerJoinAndSelect('e.payer', 'payer')
      .innerJoinAndSelect('e.group', 'grp')
      .where('p.userId = :userId', { userId })
      .orderBy('e.date', 'DESC')
      .addOrderBy('e.createdAt', 'DESC')
      .getMany();

    return participations.map((p) => ({
      id: `shared_${p.expense.id}`,
      description: p.expense.description,
      amount: Number(p.shareAmount),
      totalAmount: Number(p.expense.totalAmount),
      currency: p.expense.currency,
      date: p.expense.date instanceof Date
        ? p.expense.date.toISOString().slice(0, 10)
        : String(p.expense.date).slice(0, 10),
      groupId: p.expense.groupId,
      groupName: p.expense.group?.name ?? '',
      payerName: p.expense.payer?.fullName ?? '',
      isPayer: p.expense.payerId === userId,
      categoryLabel: p.expense.categoryLabel ?? null,
    }));
  }

  // ── Group Settings ───────────────────────────────────────────────────────

  async getGroupSettings(userId: string, groupId: string): Promise<SharedGroupSettings> {
    await this.groupsService.assertActiveMember(userId, groupId);
    const s = await this.settingsRepo.findOne({ where: { groupId } });
    if (!s) {
      // Return a virtual default without persisting
      return this.settingsRepo.create({ groupId, requiresApproval: false }) as SharedGroupSettings;
    }
    return s;
  }

  async updateGroupSettings(
    userId: string,
    groupId: string,
    dto: UpdateGroupSettingsDto,
  ): Promise<SharedGroupSettings> {
    const group = await this.groupRepo.findOne({ where: { id: groupId }, select: ['id', 'ownerId'] });
    if (!group) throw new NotFoundException('Grupo no encontrado');
    if (group.ownerId !== userId) throw new ForbiddenException('Solo el dueño del grupo puede cambiar esta configuración');

    let s = await this.settingsRepo.findOne({ where: { groupId } });
    if (!s) {
      s = this.settingsRepo.create({ groupId });
    }
    if (dto.requiresApproval !== undefined) s.requiresApproval = dto.requiresApproval;
    return this.settingsRepo.save(s);
  }

  // ── Expense Approval ─────────────────────────────────────────────────────

  async approveExpense(
    ownerId: string,
    groupId: string,
    expenseId: string,
    note?: string,
  ): Promise<SharedExpense> {
    const group = await this.groupRepo.findOne({ where: { id: groupId }, select: ['id', 'ownerId'] });
    if (!group) throw new NotFoundException('Grupo no encontrado');
    if (group.ownerId !== ownerId) throw new ForbiddenException('Solo el dueño del grupo puede aprobar gastos');

    const expense = await this.expenseRepo.findOne({
      where: { id: expenseId, groupId },
      relations: ['participants'],
    });
    if (!expense) throw new NotFoundException('Gasto no encontrado');
    if (expense.status !== SharedExpenseStatus.PENDING) {
      throw new BadRequestException('Solo se pueden aprobar gastos en estado pendiente');
    }

    await this.expenseRepo.update(expenseId, { status: SharedExpenseStatus.APPROVED });

    // Upsert approval record
    let approval = await this.approvalRepo.findOne({ where: { expenseId } });
    if (!approval) approval = this.approvalRepo.create({ expenseId, reviewerId: ownerId });
    approval.status = ApprovalStatus.APPROVED;
    approval.note = note ?? null;
    await this.approvalRepo.save(approval);

    // Notify payer
    const payer = await this.userRepo.findOne({
      where: { id: expense.payerId },
      select: ['id', 'fcmToken', 'fullName'],
    });
    if (payer?.fcmToken) {
      const groupName = (await this.groupRepo.findOne({ where: { id: groupId }, select: ['name'] }))?.name ?? 'grupo';
      await this.pushService.send({
        userId: payer.id,
        fcmToken: payer.fcmToken,
        title: 'Gasto aprobado',
        body: `Tu gasto en "${groupName}" fue aprobado.`,
        data: { type: 'expense_approved', groupId, expenseId },
        skipDailyCap: true,
      }).catch(() => {/* Non-fatal */});
    }

    return (await this.expenseRepo.findOne({
      where: { id: expenseId },
      relations: ['payer', 'participants', 'participants.user'],
    }))!;
  }

  async rejectExpense(
    ownerId: string,
    groupId: string,
    expenseId: string,
    note?: string,
  ): Promise<SharedExpense> {
    const group = await this.groupRepo.findOne({ where: { id: groupId }, select: ['id', 'ownerId'] });
    if (!group) throw new NotFoundException('Grupo no encontrado');
    if (group.ownerId !== ownerId) throw new ForbiddenException('Solo el dueño del grupo puede rechazar gastos');

    const expense = await this.expenseRepo.findOne({ where: { id: expenseId, groupId } });
    if (!expense) throw new NotFoundException('Gasto no encontrado');
    if (expense.status !== SharedExpenseStatus.PENDING) {
      throw new BadRequestException('Solo se pueden rechazar gastos en estado pendiente');
    }

    await this.expenseRepo.update(expenseId, { status: SharedExpenseStatus.PENDING });

    let approval = await this.approvalRepo.findOne({ where: { expenseId } });
    if (!approval) approval = this.approvalRepo.create({ expenseId, reviewerId: ownerId });
    approval.status = ApprovalStatus.REJECTED;
    approval.note = note ?? null;
    await this.approvalRepo.save(approval);

    // Notify payer
    const payer = await this.userRepo.findOne({
      where: { id: expense.payerId },
      select: ['id', 'fcmToken'],
    });
    if (payer?.fcmToken) {
      const groupName = (await this.groupRepo.findOne({ where: { id: groupId }, select: ['name'] }))?.name ?? 'grupo';
      await this.pushService.send({
        userId: payer.id,
        fcmToken: payer.fcmToken,
        title: 'Gasto rechazado',
        body: `Tu gasto en "${groupName}" fue rechazado.${note ? ` Motivo: ${note}` : ''}`,
        data: { type: 'expense_rejected', groupId, expenseId },
        skipDailyCap: true,
      }).catch(() => {/* Non-fatal */});
    }

    return (await this.expenseRepo.findOne({
      where: { id: expenseId },
      relations: ['payer', 'participants', 'participants.user'],
    }))!;
  }

  // ── Group Statistics ─────────────────────────────────────────────────────

  async getGroupStats(userId: string, groupId: string) {
    await this.groupsService.assertActiveMember(userId, groupId);

    const expenses = await this.expenseRepo.find({
      where: { groupId, status: SharedExpenseStatus.APPROVED },
      relations: ['payer', 'participants', 'participants.user'],
    });

    const totalAmount = expenses.reduce((s, e) => s + Number(e.totalAmount), 0);

    // By category
    const byCategory: Record<string, number> = {};
    for (const e of expenses) {
      const cat = e.categoryLabel ?? 'Sin categoría';
      byCategory[cat] = (byCategory[cat] ?? 0) + Number(e.totalAmount);
    }

    // By payer
    const byPayer: Record<string, { name: string; amount: number }> = {};
    for (const e of expenses) {
      const key = e.payerId;
      if (!byPayer[key]) byPayer[key] = { name: e.payer?.fullName ?? key, amount: 0 };
      byPayer[key].amount += Number(e.totalAmount);
    }

    // By month (last 6 months)
    const byMonth: Record<string, number> = {};
    for (const e of expenses) {
      const d = e.date instanceof Date ? e.date : new Date(e.date);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      byMonth[key] = (byMonth[key] ?? 0) + Number(e.totalAmount);
    }

    return {
      totalExpenses: expenses.length,
      totalAmount,
      averageAmount: expenses.length ? totalAmount / expenses.length : 0,
      byCategory: Object.entries(byCategory)
        .sort((a, b) => b[1] - a[1])
        .map(([label, amount]) => ({ label, amount })),
      byPayer: Object.values(byPayer).sort((a, b) => b.amount - a.amount),
      byMonth: Object.entries(byMonth)
        .sort((a, b) => a[0].localeCompare(b[0]))
        .map(([month, amount]) => ({ month, amount })),
    };
  }

  // ── Export ───────────────────────────────────────────────────────────────

  async exportGroupExpenses(userId: string, groupId: string): Promise<string> {
    await this.groupsService.assertActiveMember(userId, groupId);

    const expenses = await this.expenseRepo.find({
      where: { groupId },
      relations: ['payer', 'participants', 'participants.user'],
      order: { date: 'ASC' },
    });

    const rows: string[] = [
      'Fecha,Descripción,Monto Total,Moneda,Pagador,Categoría,Método de Pago,Participantes,Partes,Notas',
    ];

    for (const e of expenses) {
      const date = e.date instanceof Date
        ? e.date.toISOString().slice(0, 10)
        : String(e.date).slice(0, 10);

      const participantNames = e.participants.map((p) => p.user?.fullName ?? p.userId).join(';');
      const shares = e.participants.map((p) => Number(p.shareAmount).toFixed(2)).join(';');
      const note = (e.note ?? '').replace(/,/g, ' ').replace(/\n/g, ' ');

      rows.push([
        date,
        `"${e.description.replace(/"/g, '""')}"`,
        Number(e.totalAmount).toFixed(2),
        e.currency,
        `"${e.payer?.fullName ?? e.payerId}"`,
        e.categoryLabel ?? '',
        e.paymentMethod,
        `"${participantNames}"`,
        `"${shares}"`,
        `"${note}"`,
      ].join(','));
    }

    return rows.join('\n');
  }

  // ── Import ───────────────────────────────────────────────────────────────

  async importExpenses(
    currentUserId: string,
    groupId: string,
    rows: Array<{ description: string; totalAmount: number; date: string; payerName: string; participants: Array<{ name: string; amount: number }> }>,
  ): Promise<{ imported: number; skipped: number }> {
    await this.groupsService.assertActiveMember(currentUserId, groupId);

    // Load all active members for name matching
    const members = await this.memberRepo.find({
      where: { groupId, status: SharedGroupMemberStatus.ACTIVE },
      relations: ['user'],
    });

    const normalize = (name: string) => name.toLowerCase().trim();
    const memberByName = new Map(members.map((m) => [normalize(m.user?.fullName ?? ''), m.user!]));

    let imported = 0;
    let skipped = 0;

    for (const row of rows) {
      try {
        // Find payer
        const payer = memberByName.get(normalize(row.payerName));
        if (!payer) { skipped++; continue; }

        // Match participants
        const resolvedParticipants: Array<{ userId: string; shareAmount: number }> = [];
        for (const p of row.participants) {
          const user = memberByName.get(normalize(p.name));
          if (user) resolvedParticipants.push({ userId: user.id, shareAmount: p.amount });
        }
        if (resolvedParticipants.length === 0) { skipped++; continue; }

        // Validate sum
        const sum = resolvedParticipants.reduce((s, p) => s + p.shareAmount, 0);
        if (Math.abs(sum - row.totalAmount) > 0.02) { skipped++; continue; }

        const expense = this.expenseRepo.create({
          groupId,
          payerId: payer.id,
          totalAmount: row.totalAmount,
          currency: 'HNL',
          description: row.description,
          date: new Date(row.date),
          status: SharedExpenseStatus.APPROVED,
          isRecurring: false,
        });
        const saved = await this.expenseRepo.save(expense);
        await this.participantRepo.save(
          resolvedParticipants.map((p) =>
            this.participantRepo.create({ expenseId: saved.id, ...p }),
          ),
        );
        imported++;
      } catch {
        skipped++;
      }
    }

    return { imported, skipped };
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /**
   * Send push notification to participants of a changed/deleted expense,
   * respecting each user's `pushSharedExpenseChanges` preference.
   */
  private async _notifyExpenseChanged(
    actorId: string,
    groupId: string,
    expenseId: string,
    participantIds: string[],
    action: 'edit' | 'delete',
    description: string,
  ): Promise<void> {
    const targets = participantIds.filter((id) => id !== actorId);
    if (targets.length === 0) return;

    const [actor, group, users, prefs] = await Promise.all([
      this.userRepo.findOne({ where: { id: actorId }, select: ['id', 'fullName'] }),
      this.groupRepo.findOne({ where: { id: groupId }, select: ['id', 'name'] }),
      this.userRepo.find({ where: { id: In(targets) }, select: ['id', 'fullName', 'fcmToken'] }),
      this.prefsRepo.find({ where: { userId: In(targets) } }),
    ]);

    const prefsByUserId = new Map(prefs.map((p) => [p.userId, p]));
    const actorName = actor?.fullName ?? 'Alguien';
    const groupName = group?.name ?? 'grupo compartido';
    const verb = action === 'edit' ? 'editó' : 'eliminó';

    for (const user of users) {
      if (!user.fcmToken) continue;
      const pref = prefsByUserId.get(user.id);
      if (pref && pref.pushSharedExpenseChanges === false) continue;

      await this.pushService.send({
        userId: user.id,
        fcmToken: user.fcmToken,
        title: `Gasto ${action === 'edit' ? 'editado' : 'eliminado'} en ${groupName}`,
        body: `${actorName} ${verb} "${description}"`,
        data: { type: `shared_expense_${action}`, groupId, expenseId },
        skipDailyCap: true,
      }).catch(() => {/* Non-fatal */});
    }
  }

  /** Calculate the next recurrence date from a base date */
  private _calcNextRecurrence(
    baseDateStr: string,
    interval?: RecurringInterval,
    day?: number,
  ): Date | null {
    if (!interval) return null;
    const base = new Date(baseDateStr);
    if (interval === RecurringInterval.MONTHLY) {
      const next = new Date(base);
      next.setMonth(next.getMonth() + 1);
      if (day && day >= 1 && day <= 28) next.setDate(day);
      return next;
    }
    if (interval === RecurringInterval.WEEKLY) {
      const next = new Date(base);
      next.setDate(next.getDate() + 7);
      return next;
    }
    return null;
  }
}
