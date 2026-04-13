import { IsBoolean, IsOptional } from 'class-validator';

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
}
