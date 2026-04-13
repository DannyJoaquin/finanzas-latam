import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../modules/users/user.entity';
import { Expense } from '../modules/expenses/expense.entity';
import { PushNotificationService } from '../common/services/push-notification.service';
import { NotificationPreferencesService } from '../modules/users/notification-preferences.service';

/**
 * Sends an enriched weekly spending summary every Monday at 9:00 AM.
 * Includes: total spent this week vs previous week, top category, and
 * a qualitative status (mejor / peor / estable).
 *
 * Only sends if user has push_weekly_summary = true.
 */
@Injectable()
export class WeeklySummaryJob {
  private readonly logger = new Logger(WeeklySummaryJob.name);

  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    private pushService: PushNotificationService,
    private notificationPrefsService: NotificationPreferencesService,
  ) {}

  @Cron('0 9 * * 1') // Every Monday at 09:00
  async run(): Promise<void> {
    this.logger.log('Running weekly summary job...');

    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const twoWeeksAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

    const users = await this.userRepo.find({
      where: { isActive: true },
      select: ['id', 'fcmToken', 'fullName', 'currency'],
    });

    const withToken = users.filter((u) => !!u.fcmToken);
    let sent = 0;

    for (const user of withToken) {
      try {
        const prefs = await this.notificationPrefsService.findOrCreateDefaults(user.id);
        if (!prefs.pushWeeklySummary) continue;

        const currency = user.currency ?? 'HNL';
        const thisWeek = await this._weeklyTotal(user.id, weekAgo, now);
        const prevWeek = await this._weeklyTotal(user.id, twoWeeksAgo, weekAgo);
        const topCategory = await this._topCategory(user.id, weekAgo, now);

        const body = this._buildSummaryBody(thisWeek, prevWeek, topCategory, currency);

        const ok = await this.pushService.send({
          userId: user.id,
          fcmToken: user.fcmToken,
          title: 'Tu resumen de la semana',
          body,
          data: {
            type: 'weekly_summary',
            total: thisWeek.toFixed(2),
            prevTotal: prevWeek.toFixed(2),
            currency,
          },
        });
        if (ok) sent++;
      } catch (err) {
        this.logger.error(`Weekly summary failed for user ${user.id}`, err);
      }
    }

    this.logger.log(`Weekly summary sent to ${sent}/${withToken.length} users`);
  }

  private _buildSummaryBody(
    thisWeek: number,
    prevWeek: number,
    topCategory: { name: string; total: number } | null,
    currency: string,
  ): string {
    const fmt = (n: number) => n.toFixed(0);

    // Determine status vs previous week
    let statusPart = '';
    if (prevWeek > 0) {
      const pctChange = ((thisWeek - prevWeek) / prevWeek) * 100;
      if (pctChange < -5) {
        statusPart = ` Vas ${Math.abs(Math.round(pctChange))}% mejor que la semana pasada.`;
      } else if (pctChange > 5) {
        statusPart = ` Vas ${Math.round(pctChange)}% por encima de la semana pasada.`;
      } else {
        statusPart = ' Ritmo estable respecto a la semana pasada.';
      }
    }

    // Category part
    let categoryPart = '';
    if (topCategory && thisWeek > 0) {
      const pct = Math.round((topCategory.total / thisWeek) * 100);
      categoryPart = ` ${topCategory.name} fue tu categoría principal (${pct}%).`;
    }

    return (
      `Esta semana gastaste ${currency} ${fmt(thisWeek)}.` +
      categoryPart +
      statusPart
    );
  }

  private async _weeklyTotal(userId: string, from: Date, to: Date): Promise<number> {
    const result = await this.expenseRepo
      .createQueryBuilder('e')
      .select('COALESCE(SUM(CAST(e.amount AS FLOAT)), 0)', 'total')
      .where('e.userId = :userId', { userId })
      .andWhere('e.date BETWEEN :from AND :to', { from, to })
      .getRawOne<{ total: string }>();

    return parseFloat(result?.total ?? '0');
  }

  private async _topCategory(
    userId: string,
    from: Date,
    to: Date,
  ): Promise<{ name: string; total: number } | null> {
    const row = await this.expenseRepo
      .createQueryBuilder('e')
      .innerJoin('e.category', 'c')
      .select('c.name', 'name')
      .addSelect('COALESCE(SUM(CAST(e.amount AS FLOAT)), 0)', 'total')
      .where('e.userId = :userId', { userId })
      .andWhere('e.date BETWEEN :from AND :to', { from, to })
      .groupBy('c.name')
      .orderBy('total', 'DESC')
      .limit(1)
      .getRawOne<{ name: string; total: string }>();

    if (!row) return null;
    return { name: row.name, total: parseFloat(row.total) };
  }
}

