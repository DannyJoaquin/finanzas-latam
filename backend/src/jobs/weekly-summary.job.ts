import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import { User } from '../modules/users/user.entity';
import { Expense } from '../modules/expenses/expense.entity';
import { PushNotificationService } from '../common/services/push-notification.service';

/**
 * Sends a weekly spending summary push notification every Monday at 9:00 AM.
 * Includes total spent in the last 7 days.
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
  ) {}

  @Cron('0 9 * * 1') // Every Monday at 09:00
  async run(): Promise<void> {
    this.logger.log('Running weekly summary job...');

    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const users = await this.userRepo.find({
      where: { isActive: true },
      select: ['id', 'fcmToken', 'fullName', 'currency'],
    });

    const withToken = users.filter((u) => !!u.fcmToken);
    let sent = 0;

    for (const user of withToken) {
      const total = await this._weeklyTotal(user.id, weekAgo, now);
      const formattedTotal = total.toFixed(2);
      const currency = user.currency ?? 'HNL';

      const sent_ok = await this.pushService.send({
        userId: user.id,
        fcmToken: user.fcmToken,
        title: 'Tu resumen de la semana',
        body: `Gastaste ${currency} ${formattedTotal} esta semana. ¡Revisa tus presupuestos!`,
        data: { type: 'weekly_summary', total: formattedTotal, currency },
      });
      if (sent_ok) sent++;
    }

    this.logger.log(`Weekly summary sent to ${sent}/${withToken.length} users`);
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
}
