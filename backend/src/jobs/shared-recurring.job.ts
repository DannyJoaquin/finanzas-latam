import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { In, LessThanOrEqual, Repository } from 'typeorm';
import { SharedExpense, RecurringInterval, SharedExpenseStatus } from '../modules/shared-groups/entities/shared-expense.entity';
import { SharedExpenseParticipant } from '../modules/shared-groups/entities/shared-expense-participant.entity';
import { PushNotificationService } from '../common/services/push-notification.service';
import { User } from '../modules/users/user.entity';
import { SharedGroup } from '../modules/shared-groups/entities/shared-group.entity';

@Injectable()
export class SharedRecurringJob {
  private readonly logger = new Logger(SharedRecurringJob.name);

  constructor(
    @InjectRepository(SharedExpense)
    private expenseRepo: Repository<SharedExpense>,
    @InjectRepository(SharedExpenseParticipant)
    private participantRepo: Repository<SharedExpenseParticipant>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(SharedGroup)
    private groupRepo: Repository<SharedGroup>,
    private pushService: PushNotificationService,
  ) {}

  /** Runs daily at 08:00 */
  @Cron('0 8 * * *')
  async run(): Promise<void> {
    this.logger.log('Running SharedRecurringJob...');

    const now = new Date();

    // Find all recurring expenses whose next recurrence date has arrived
    const due = await this.expenseRepo.find({
      where: {
        isRecurring: true,
        nextRecurrenceAt: LessThanOrEqual(now),
      },
      relations: ['participants'],
    });

    this.logger.log(`Found ${due.length} recurring expense(s) to process`);

    for (const original of due) {
      try {
        // Create the new expense (clone)
        const newDate = this._calcNextDate(
          original.nextRecurrenceAt ?? now,
          original.recurringInterval,
        );

        const cloned = this.expenseRepo.create({
          groupId: original.groupId,
          payerId: original.payerId,
          totalAmount: original.totalAmount,
          currency: original.currency,
          description: original.description,
          categoryLabel: original.categoryLabel,
          paymentMethod: original.paymentMethod,
          note: original.note,
          date: original.nextRecurrenceAt ?? now,
          status: SharedExpenseStatus.APPROVED,
          isRecurring: false, // cloned expense is a one-time instance
          receiptUrl: null,
          recurringInterval: null,
          recurringDay: null,
          nextRecurrenceAt: null,
        });
        const saved = await this.expenseRepo.save(cloned);

        // Clone participants
        const participants = original.participants.map((p) =>
          this.participantRepo.create({
            expenseId: saved.id,
            userId: p.userId,
            shareAmount: p.shareAmount,
            isSettled: false,
          }),
        );
        await this.participantRepo.save(participants);

        // Advance the next_recurrence_at on the original template
        await this.expenseRepo.update(original.id, {
          nextRecurrenceAt: newDate,
        });

        // Notify participants
        await this._notifyParticipants(original, saved);

        this.logger.log(`Created recurring instance for expense ${original.id}`);
      } catch (err) {
        this.logger.error(`Failed to process recurring expense ${original.id}: ${err}`);
      }
    }
  }

  private _calcNextDate(from: Date, interval: RecurringInterval | null): Date {
    const next = new Date(from);
    if (interval === RecurringInterval.MONTHLY) {
      next.setMonth(next.getMonth() + 1);
    } else if (interval === RecurringInterval.WEEKLY) {
      next.setDate(next.getDate() + 7);
    } else {
      // Default: 1 month
      next.setMonth(next.getMonth() + 1);
    }
    return next;
  }

  private async _notifyParticipants(
    template: SharedExpense,
    newExpense: SharedExpense,
  ): Promise<void> {
    const participantIds = newExpense.participants?.map((p) => p.userId) ?? [];
    const targets = participantIds.filter((id) => id !== template.payerId);
    if (targets.length === 0) return;

    const [payer, group, users] = await Promise.all([
      this.userRepo.findOne({ where: { id: template.payerId }, select: ['id', 'fullName'] }),
      this.groupRepo.findOne({ where: { id: template.groupId }, select: ['id', 'name'] }),
      this.userRepo.find({ where: { id: In(targets) }, select: ['id', 'fcmToken'] }),
    ]);

    const payerName = payer?.fullName ?? 'El pagador';
    const groupName = group?.name ?? 'grupo compartido';

    for (const user of users) {
      if (!user.fcmToken) continue;
      await this.pushService.send({
        userId: user.id,
        fcmToken: user.fcmToken,
        title: `Gasto recurrente en ${groupName}`,
        body: `${payerName} registró "${template.description}" (recurrente)`,
        data: { type: 'shared_expense_recurring', groupId: template.groupId, expenseId: newExpense.id },
        skipDailyCap: true,
      }).catch(() => {/* Non-fatal */});
    }
  }
}
