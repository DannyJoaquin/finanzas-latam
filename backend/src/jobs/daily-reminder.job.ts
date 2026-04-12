import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../modules/users/user.entity';
import { PushNotificationService } from '../common/services/push-notification.service';

/**
 * Sends a daily spending reminder push notification to all active users
 * who have an FCM token registered.
 *
 * Cron: 08:00 AM server time — early morning reminder to stay on budget.
 */
@Injectable()
export class DailyReminderJob {
  private readonly logger = new Logger(DailyReminderJob.name);

  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    private pushService: PushNotificationService,
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

    for (const user of withToken) {
      const sent_ok = await this.pushService.send({
        userId: user.id,
        fcmToken: user.fcmToken,
        title: '¿Cómo vas con tus gastos hoy?',
        body: 'Registra tus gastos de hoy para mantener control de tu presupuesto.',
        data: { type: 'daily_reminder' },
      });
      if (sent_ok) sent++;
    }

    this.logger.log(`Daily reminder sent to ${sent}/${withToken.length} users`);
  }
}
