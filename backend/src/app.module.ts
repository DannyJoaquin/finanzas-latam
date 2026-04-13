import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { APP_GUARD } from '@nestjs/core';
import { RedisModule } from '@nestjs-modules/ioredis';

import appConfig from './config/app.config';
import databaseConfig from './config/database.config';
import redisConfig from './config/redis.config';
import jwtConfig from './config/jwt.config';
import awsConfig from './config/aws.config';
import googleConfig from './config/google.config';

import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { IncomesModule } from './modules/incomes/incomes.module';
import { ExpensesModule } from './modules/expenses/expenses.module';
import { BudgetsModule } from './modules/budgets/budgets.module';
import { CashModule } from './modules/cash/cash.module';
import { GoalsModule } from './modules/goals/goals.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { InsightsModule } from './modules/insights/insights.module';
import { RulesModule } from './modules/rules/rules.module';
import { CreditCardsModule } from './modules/credit-cards/credit-cards.module';
import { CategorizationModule } from './modules/categorization/categorization.module';
import { GlobalJwtAuthGuard } from './modules/auth/guards/global-jwt-auth.guard';

// Jobs
import { InsightsGeneratorJob } from './jobs/insights-generator.job';
import { BudgetAlertsJob } from './jobs/budget-alerts.job';
import { DailyReminderJob } from './jobs/daily-reminder.job';
import { WeeklySummaryJob } from './jobs/weekly-summary.job';

// Common services
import { PushNotificationService } from './common/services/push-notification.service';
import { NotificationRoutingService } from './common/services/notification-routing.service';

// Entities for job repositories
import { User } from './modules/users/user.entity';
import { Budget } from './modules/budgets/budget.entity';
import { Expense } from './modules/expenses/expense.entity';
import { Insight } from './modules/insights/insight.entity';

@Module({
  imports: [
    // ── Config ────────────────────────────────────────────────────────────
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig, redisConfig, jwtConfig, awsConfig, googleConfig],
    }),

    // ── Database ──────────────────────────────────────────────────────────
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        ...config.get('database'),
      }),
    }),

    // ── Redis ────────────────────────────────────────────────────────────
    RedisModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'single',
        options: {
          host: config.get<string>('redis.host'),
          port: config.get<number>('redis.port'),
          password: config.get<string>('redis.password') || undefined,
        },
      }),
    }),

    // ── Rate limiting ─────────────────────────────────────────────────────
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        throttlers: [{
          ttl: config.get<number>('THROTTLE_TTL', 60) * 1000,
          limit: config.get<number>('THROTTLE_LIMIT', 200),
        }],
      }),
    }),

    // ── Scheduling (cron jobs) ────────────────────────────────────────────
    ScheduleModule.forRoot(),

    // ── Feature modules ───────────────────────────────────────────────────
    TypeOrmModule.forFeature([User, Budget, Expense, Insight]),
    AuthModule,
    UsersModule,
    CategoriesModule,
    IncomesModule,
    ExpensesModule,
    BudgetsModule,
    CashModule,
    GoalsModule,
    AnalyticsModule,
    InsightsModule,
    RulesModule,
    CreditCardsModule,
    CategorizationModule,
  ],
  providers: [
    // Global JWT guard — all routes require auth unless @Public()
    { provide: APP_GUARD, useClass: GlobalJwtAuthGuard },
    // Global rate limiting
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // Cron jobs
    InsightsGeneratorJob,
    BudgetAlertsJob,
    DailyReminderJob,
    WeeklySummaryJob,
    // Shared services
    PushNotificationService,
    NotificationRoutingService,
  ],
})
export class AppModule {}

