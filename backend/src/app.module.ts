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
import mailConfig from './config/mail.config';

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
import { SharedGroupsModule } from './modules/shared-groups/shared-groups.module';
import { RecurringExpensesModule } from './modules/recurring-expenses/recurring-expenses.module';
import { GlobalJwtAuthGuard } from './modules/auth/guards/global-jwt-auth.guard';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { HealthController } from './health.controller';

// Jobs
import { InsightsGeneratorJob } from './jobs/insights-generator.job';
import { BudgetAlertsJob } from './jobs/budget-alerts.job';
import { DailyReminderJob } from './jobs/daily-reminder.job';
import { WeeklySummaryJob } from './jobs/weekly-summary.job';
import { SharedRecurringJob } from './jobs/shared-recurring.job';
import { DebtReminderJob } from './jobs/debt-reminder.job';

// Common services
import { PushNotificationService } from './common/services/push-notification.service';
import { NotificationRoutingService } from './common/services/notification-routing.service';

// Entities for job repositories
import { User } from './modules/users/user.entity';
import { Budget } from './modules/budgets/budget.entity';
import { Expense } from './modules/expenses/expense.entity';
import { Insight } from './modules/insights/insight.entity';
import { SharedExpense } from './modules/shared-groups/entities/shared-expense.entity';
import { SharedExpenseParticipant } from './modules/shared-groups/entities/shared-expense-participant.entity';
import { SharedGroupMember } from './modules/shared-groups/entities/shared-group-member.entity';
import { SharedGroup } from './modules/shared-groups/entities/shared-group.entity';
import { SharedSettlement } from './modules/shared-groups/entities/shared-settlement.entity';
import { UserNotificationPreferences } from './modules/users/user-notification-preferences.entity';

@Module({
  imports: [
    // ── Config ────────────────────────────────────────────────────────────
    ConfigModule.forRoot({
      isGlobal: true,
      load: [
        appConfig,
        databaseConfig,
        redisConfig,
        jwtConfig,
        awsConfig,
        googleConfig,
        mailConfig,
      ],
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
        options: (() => {
          const configuredUrl = config.get<string>('redis.url');
          const parsed = configuredUrl ? new URL(configuredUrl) : undefined;
          const password = parsed?.password
            ? decodeURIComponent(parsed.password)
            : config.get<string>('redis.password') || undefined;
          return {
            host: parsed?.hostname ?? config.get<string>('redis.host'),
            port: parsed?.port
              ? Number(parsed.port)
              : config.get<number>('redis.port'),
            username: parsed?.username
              ? decodeURIComponent(parsed.username)
              : undefined,
            password,
            tls:
              configuredUrl?.startsWith('rediss://') ||
              config.get<boolean>('redis.tls')
                ? {}
                : undefined,
          };
        })(),
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
    TypeOrmModule.forFeature([
      User, Budget, Expense, Insight,
      SharedExpense, SharedExpenseParticipant, SharedGroupMember,
      SharedGroup, SharedSettlement, UserNotificationPreferences,
    ]),
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
    SharedGroupsModule,
    RecurringExpensesModule,
  ],
  controllers: [AppController, HealthController],
  providers: [
    AppService,
    // Global JWT guard — all routes require auth unless @Public()
    { provide: APP_GUARD, useClass: GlobalJwtAuthGuard },
    // Global rate limiting
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // Cron jobs
    InsightsGeneratorJob,
    BudgetAlertsJob,
    DailyReminderJob,
    WeeklySummaryJob,
    SharedRecurringJob,
    DebtReminderJob,
    // Shared services
    PushNotificationService,
    NotificationRoutingService,
  ],
})
export class AppModule {}

