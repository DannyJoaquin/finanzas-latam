import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator';

export class UpdateNotificationPreferencesDto {
  @IsOptional() @IsBoolean() pushBudgetAlerts?: boolean;
  @IsOptional() @IsBoolean() pushDailyReminder?: boolean;
  @IsOptional() @IsBoolean() pushWeeklySummary?: boolean;
  @IsOptional() @IsBoolean() pushImportantInsights?: boolean;
  @IsOptional() @IsBoolean() pushCriticalFinancialAlerts?: boolean;
  @IsOptional() @IsBoolean() pushMotivation?: boolean;
  @IsOptional() @IsBoolean() localCardCutoffAlerts?: boolean;
  @IsOptional() @IsBoolean() localCardDue5d?: boolean;
  @IsOptional() @IsBoolean() localCardDue1d?: boolean;
  @IsOptional() @IsBoolean() localCardPendingBalance?: boolean;
  @IsOptional() @IsBoolean() inappSavingsOpportunities?: boolean;
  @IsOptional() @IsBoolean() inappPatterns?: boolean;
  @IsOptional() @IsBoolean() inappMotivation?: boolean;

  // Shared groups
  @IsOptional() @IsBoolean() pushSharedExpenseChanges?: boolean;

  /** null = disable debt reminders; 1–365 = days threshold */
  @IsOptional() @IsInt() @Min(1) @Max(365) debtReminderDays?: number | null;
}
