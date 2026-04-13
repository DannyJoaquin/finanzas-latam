import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Insight } from './insight.entity';
import { User } from '../users/user.entity';
import { Expense } from '../expenses/expense.entity';
import { Budget } from '../budgets/budget.entity';
import { InsightsController } from './insights.controller';
import { InsightsService } from './insights.service';
import { InsightsGeneratorService } from './insights-generator.service';
import { AnalyticsModule } from '../analytics/analytics.module';
import { PushNotificationService } from '../../common/services/push-notification.service';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [TypeOrmModule.forFeature([Insight, User, Expense, Budget]), AnalyticsModule, UsersModule],
  controllers: [InsightsController],
  providers: [InsightsService, InsightsGeneratorService, PushNotificationService],
  exports: [InsightsService, InsightsGeneratorService],
})
export class InsightsModule {}
