import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../modules/users/user.entity';
import { InsightsGeneratorService } from '../modules/insights/insights-generator.service';

@Injectable()
export class InsightsGeneratorJob {
  private readonly logger = new Logger(InsightsGeneratorJob.name);

  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    private insightsGenerator: InsightsGeneratorService,
  ) {}

  /** Runs every day at 2:00 AM server time */
  @Cron('0 2 * * *')
  async run(): Promise<void> {
    this.logger.log('Starting nightly insights generation...');
    const users = await this.userRepo.find({ where: { isActive: true } });
    let processed = 0;
    for (const user of users) {
      try {
        await this.insightsGenerator.generateForUser(user.id);
        processed++;
      } catch (err) {
        this.logger.error(`Failed to generate insights for user ${user.id}`, err);
      }
    }
    this.logger.log(`Insights generated for ${processed}/${users.length} users`);
  }
}
