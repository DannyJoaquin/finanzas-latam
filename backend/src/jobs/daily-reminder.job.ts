import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../modules/users/user.entity';
import { Expense } from '../modules/expenses/expense.entity';
import { Insight, InsightPriority, InsightType } from '../modules/insights/insight.entity';
import { PushNotificationService } from '../common/services/push-notification.service';
import { NotificationPreferencesService } from '../modules/users/notification-preferences.service';

/**
 * Sends a conditional daily reminder push to users who have at least one
 * of these conditions true:
 *   1. Did not log any expense in the last 24 hours
 *   2. Has an active BUDGET_WARNING insight
 *   3. Has an active STREAK insight at risk (no expense today yet)
 *
 * The message copy adapts per condition.
 * Only runs if the user has push_daily_reminder = true.
 */
@Injectable()
export class DailyReminderJob {
  private readonly logger = new Logger(DailyReminderJob.name);

  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    @InjectRepository(Insight)
    private insightRepo: Repository<Insight>,
    private pushService: PushNotificationService,
    private notificationPrefsService: NotificationPreferencesService,
  ) {}

  @Cron('0 8 * * *')
  async run(): Promise<void> {
    this.logger.log('Running daily reminder job...');

    const users = await this.userRepo.find({
      where: { isActive: true },
      select: ['id', 'fcmToken', 'fullName'],
    });

    const withToken = users.filter((u) => !!u.fcmToken);
    let sent = 0;

    const now = new Date();
    const since24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    for (const user of withToken) {
      try {
        const prefs = await this.notificationPrefsService.findOrCreateDefaults(user.id);
        if (!prefs.pushDailyReminder) continue;

        // Condition 1: no expense in last 24h
        const recentCount = await this.expenseRepo
          .createQueryBuilder('e')
          .where('e.userId = :uid', { uid: user.id })
          .andWhere('e.createdAt > :since', { since: since24h })
          .getCount();
        const noRecentExpense = recentCount === 0;

        // Condition 2: active budget warning
        const hasBudgetWarning = await this.insightRepo
          .createQueryBuilder('i')
          .where('i.userId = :uid', { uid: user.id })
          .andWhere('i.type = :type', { type: InsightType.BUDGET_WARNING })
          .andWhere('i.isDismissed = false')
          .andWhere('(i.expiresAt IS NULL OR i.expiresAt > NOW())')
          .getCount()
          .then((c) => c > 0);

        // Condition 3: has active streak but no expense yet today (racha at risk)
        const hasStreakAtRisk = await (async () => {
          const hasStreak = await this.insightRepo
            .createQueryBuilder('i')
            .where('i.userId = :uid', { uid: user.id })
            .andWhere('i.type = :type', { type: InsightType.STREAK })
            .andWhere('i.isDismissed = false')
            .andWhere('(i.expiresAt IS NULL OR i.expiresAt > NOW())')
            .getCount()
            .then((c) => c > 0);
          if (!hasStreak) return false;
          const todayCount = await this.expenseRepo
            .createQueryBuilder('e')
            .where('e.userId = :uid', { uid: user.id })
            .andWhere('e.date >= :todayStart', { todayStart })
            .getCount();
          return todayCount === 0;
        })();

        if (!noRecentExpense && !hasBudgetWarning && !hasStreakAtRisk) continue;

        // Pick contextual copy — budget warning takes priority
        let title: string;
        let body: string;

        if (hasBudgetWarning) {
          title = '¡Cuidado con tu presupuesto!';
          body = 'Vas a un ritmo acelerado. Revisa tus gastos para mantenerte en control.';
        } else if (hasStreakAtRisk) {
          title = '¡Tu racha está en juego!';
          body = '¿Ya registraste algún gasto hoy? No lo dejes para después y mantén tu racha activa.';
        } else {
          title = '¿Cómo van tus gastos hoy?';
          body = 'No registraste gastos ayer. Mantén el control registrando tus movimientos de hoy.';
        }

        const ok = await this.pushService.send({
          userId: user.id,
          fcmToken: user.fcmToken,
          title,
          body,
          data: { type: 'daily_reminder' },
        });
        if (ok) sent++;
      } catch (err) {
        this.logger.error(`Daily reminder failed for user ${user.id}`, err);
      }
    }

    this.logger.log(`Daily reminder sent to ${sent}/${withToken.length} users`);
  }
}

