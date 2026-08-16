import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';
import { PaymentMethod } from '../../expenses/expense.entity';
import { RecurringFrequency } from '../recurring-expense.entity';

export class CreateRecurringExpenseDto {
  @IsString()
  @Length(1, 150)
  name: string;

  @IsNumber()
  @IsPositive()
  amount: number;

  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @IsUUID()
  categoryId: string;

  @IsOptional()
  @IsEnum(PaymentMethod)
  paymentMethod?: PaymentMethod;

  @IsOptional()
  @IsUUID()
  cashAccountId?: string | null;

  @IsOptional()
  @IsUUID()
  creditCardId?: string | null;

  @IsOptional()
  @IsString()
  @Length(1, 1000)
  notes?: string | null;

  @IsEnum(RecurringFrequency)
  frequency: RecurringFrequency;

  @IsInt()
  @Min(1)
  @Max(31)
  executionDay: number;

  @IsDateString()
  startDate: string;
}

export class UpdateRecurringExpenseDto {
  @IsOptional()
  @IsString()
  @Length(1, 150)
  name?: string;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsEnum(PaymentMethod)
  paymentMethod?: PaymentMethod;

  @IsOptional()
  @IsUUID()
  cashAccountId?: string | null;

  @IsOptional()
  @IsUUID()
  creditCardId?: string | null;

  @IsOptional()
  @IsString()
  @Length(1, 1000)
  notes?: string | null;

  @IsOptional()
  @IsEnum(RecurringFrequency)
  frequency?: RecurringFrequency;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  executionDay?: number;

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
