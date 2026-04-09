import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Insight } from './insight.entity';
import { User } from '../users/user.entity';
import { Expense } from '../expenses/expense.entity';
import { InsightsController } from './insights.controller';
import { InsightsService } from './insights.service';
import { InsightsGeneratorService } from './insights-generator.service';
import { AnalyticsModule } from '../analytics/analytics.module';

@Module({
  imports: [TypeOrmModule.forFeature([Insight, User, Expense]), AnalyticsModule],
  controllers: [InsightsController],
  providers: [InsightsService, InsightsGeneratorService],
  exports: [InsightsService, InsightsGeneratorService],
})
export class InsightsModule {}
