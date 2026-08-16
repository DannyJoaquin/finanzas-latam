import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUrl,
  IsUUID,
  Length,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { RecurringInterval, SharedExpensePaymentMethod } from './entities/shared-expense.entity';
import { SharedSettlementPaymentMethod } from './entities/shared-settlement.entity';

// ── Groups ────────────────────────────────────────────────────────────────────

export class CreateGroupDto {
  @IsString()
  @IsNotEmpty()
  @Length(1, 120)
  name: string;

  @IsOptional()
  @IsString()
  @Length(0, 300)
  description?: string;

  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;
}

export class JoinGroupDto {
  @IsString()
  @IsNotEmpty()
  @Length(1, 8)
  code: string;
}

// ── Shared Expenses ───────────────────────────────────────────────────────────

export class ParticipantShareDto {
  @IsUUID()
  userId: string;

  @IsNumber()
  @IsPositive()
  shareAmount: number;
}

export class CreateSharedExpenseDto {
  @IsUUID()
  payerId: string;

  @IsNumber()
  @IsPositive()
  totalAmount: number;

  @IsString()
  @IsNotEmpty()
  @Length(1, 255)
  description: string;

  @IsDateString()
  date: string;

  @IsOptional()
  @IsEnum(SharedExpensePaymentMethod)
  paymentMethod?: SharedExpensePaymentMethod;

  @IsOptional()
  @IsString()
  @Length(0, 100)
  categoryLabel?: string;

  @IsOptional()
  @IsString()
  note?: string;

  /**
   * Optional cash account ID for the payer — used to record the WITHDRAWAL
   * in the cash module when payment_method = 'cash'.
   */
  @IsOptional()
  @IsUUID()
  cashAccountId?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ParticipantShareDto)
  participants: ParticipantShareDto[];

  // ── New features ─────────────────────────────────────────────────────────

  /** URL of receipt photo previously uploaded to Firebase Storage */
  @IsOptional()
  @IsUrl()
  receiptUrl?: string;

  /** Whether this expense repeats automatically */
  @IsOptional()
  @IsBoolean()
  isRecurring?: boolean;

  @IsOptional()
  @IsEnum(RecurringInterval)
  recurringInterval?: RecurringInterval;

  /** Day-of-month (1–28) for monthly; day-of-week (1=Mon) for weekly */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  recurringDay?: number;
}

export class UpdateSharedExpenseDto {
  @IsOptional()
  @IsNumber()
  @IsPositive()
  totalAmount?: number;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @Length(1, 255)
  description?: string;

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsEnum(SharedExpensePaymentMethod)
  paymentMethod?: SharedExpensePaymentMethod;

  @IsOptional()
  @IsString()
  @Length(0, 100)
  categoryLabel?: string;

  @IsOptional()
  @IsString()
  note?: string;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ParticipantShareDto)
  participants?: ParticipantShareDto[];

  @IsOptional()
  @IsUrl()
  receiptUrl?: string;

  @IsOptional()
  @IsBoolean()
  isRecurring?: boolean;

  @IsOptional()
  @IsEnum(RecurringInterval)
  recurringInterval?: RecurringInterval;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  recurringDay?: number;
}

// ── Group Settings ────────────────────────────────────────────────────────────

export class UpdateGroupSettingsDto {
  @IsOptional()
  @IsBoolean()
  requiresApproval?: boolean;
}

// ── Expense Approval ──────────────────────────────────────────────────────────

export class ApproveExpenseDto {
  @IsOptional()
  @IsString()
  @Length(0, 300)
  note?: string;
}

// ── Import ────────────────────────────────────────────────────────────────────

export class ImportExpenseRowDto {
  @IsString()
  @IsNotEmpty()
  description: string;

  @IsNumber()
  @IsPositive()
  totalAmount: number;

  @IsDateString()
  date: string;

  @IsString()
  payerName: string;

  @IsArray()
  participants: Array<{ name: string; amount: number }>;
}

// ── Settlements ───────────────────────────────────────────────────────────────

export class CreateSettlementDto {
  @IsUUID()
  receiverId: string;

  @IsNumber()
  @IsPositive()
  amount: number;

  @IsDateString()
  date: string;

  @IsOptional()
  @IsEnum(SharedSettlementPaymentMethod)
  paymentMethod?: SharedSettlementPaymentMethod;

  @IsOptional()
  @IsString()
  note?: string;

  /**
   * Optional cash account ID — used to record the WITHDRAWAL (for the payer)
   * and DEPOSIT (for the receiver if they share the same account) in the cash
   * module, but only when payment_method = 'cash'.
   */
  @IsOptional()
  @IsUUID()
  payerCashAccountId?: string;

  @IsOptional()
  @IsUUID()
  receiverCashAccountId?: string;
}

export class UpdateSettlementDto {
  @IsOptional()
  @IsNumber()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsEnum(SharedSettlementPaymentMethod)
  paymentMethod?: SharedSettlementPaymentMethod;

  @IsOptional()
  @IsString()
  @Length(0, 300)
  note?: string;
}
