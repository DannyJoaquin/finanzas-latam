import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThan, In, Repository } from 'typeorm';
import { User } from '../modules/users/user.entity';
import { Insight, InsightPriority, InsightType } from '../modules/insights/insight.entity';
import { InsightsGeneratorService } from '../modules/insights/insights-generator.service';
import { PushNotificationService } from '../common/services/push-notification.service';
import { NotificationPreferencesService } from '../modules/users/notification-preferences.service';
import { NotificationRoutingService } from '../common/services/notification-routing.service';

/** Priority order for picking which insight gets the push slot */
const PRIORITY_ORDER: Record<InsightPriority, number> = {
  [InsightPriority.CRITICAL]: 4,
  [InsightPriority.HIGH]: 3,
  [InsightPriority.MEDIUM]: 2,
  [InsightPriority.LOW]: 1,
};

@Injectable()
export class InsightsGeneratorJob {
  private readonly logger = new Logger(InsightsGeneratorJob.name);

  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(Insight)
    private insightRepo: Repository<Insight>,
    private insightsGenerator: InsightsGeneratorService,
    private pushService: PushNotificationService,
    private notificationPrefsService: NotificationPreferencesService,
    private routingService: NotificationRoutingService,
  ) {}

  /** Runs every day at 2:00 AM server time */
  @Cron('0 2 * * *')
  async run(): Promise<void> {
    this.logger.log('Starting nightly insights generation...');

    // ── 1. Purge expired insights to keep the DB clean ───────────────────
    const deleted = await this.insightRepo.delete({
      isDismissed: false,
      expiresAt: LessThan(new Date()),
    });
    if ((deleted.affected ?? 0) > 0) {
      this.logger.log(`Purged ${deleted.affected} expired insights`);
    }

    // ── 2. Generate fresh insights and send pushes ────────────────────────
    const users = await this.userRepo.find({ where: { isActive: true } });
    const cutoff = new Date(Date.now() - 5 * 60 * 1000); // insights created in last 5 min
    let processed = 0;

    for (const user of users) {
      try {
        await this.insightsGenerator.generateForUser(user.id);
        processed++;

        if (user.fcmToken) {
          const prefs = await this.notificationPrefsService.findOrCreateDefaults(user.id);

          // Find HIGH/CRITICAL insights freshly created this run,
          // excluding streak/achievement (motivation types)
          const freshInsights = await this.insightRepo
            .createQueryBuilder('i')
            .where('i.userId = :uid', { uid: user.id })
            .andWhere('i.isDismissed = false')
            .andWhere('i.priority IN (:...priorities)', {
              priorities: [InsightPriority.HIGH, InsightPriority.CRITICAL],
            })
            .andWhere('i.type NOT IN (:...excluded)', {
              excluded: [InsightType.STREAK, InsightType.ACHIEVEMENT],
            })
            .andWhere('i.generatedAt > :cutoff', { cutoff })
            .getMany();

          // Filter further by user prefs
          const eligible = freshInsights.filter((insight) =>
            this.routingService.shouldSendPush(insight.type, insight.priority, prefs),
          );

          if (eligible.length > 0) {
            // Send only the top-priority one to stay within the daily cap
            const top = eligible.sort(
              (a, b) => PRIORITY_ORDER[b.priority] - PRIORITY_ORDER[a.priority],
            )[0];
            await this.pushService.send({
              userId: user.id,
              fcmToken: user.fcmToken,
              title: top.title,
              body: top.body,
              data: { type: 'insight', insightId: top.id },
            });
          }
        }
      } catch (err) {
        this.logger.error(`Failed to generate insights for user ${user.id}`, err);
      }
    }
    this.logger.log(`Insights generated for ${processed}/${users.length} users`);
  }
}

