import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Length,
} from 'class-validator';
import { ExpenseSource, PaymentMethod } from '../expense.entity';

export class CreateExpenseDto {
  @IsNumber()
  @IsPositive()
  amount: number;

  @IsDateString()
  date: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsString()
  @Length(1, 255)
  description?: string;

  @IsOptional()
  @IsEnum(PaymentMethod)
  paymentMethod?: PaymentMethod;

  @IsOptional()
  tags?: string[];

  @IsOptional()
  locationLat?: number;

  @IsOptional()
  locationLng?: number;

  @IsOptional()
  @IsString()
  locationName?: string;

  @IsOptional()
  @IsUUID()
  cashAccountId?: string;

  @IsOptional()
  @IsEnum(ExpenseSource)
  source?: ExpenseSource;
}

export class UpdateExpenseDto {
  @IsOptional()
  @IsNumber()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsString()
  @Length(1, 255)
  description?: string;

  @IsOptional()
  @IsEnum(PaymentMethod)
  paymentMethod?: PaymentMethod;

  @IsOptional()
  tags?: string[];
}

export class FilterExpensesDto {
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsEnum(PaymentMethod)
  paymentMethod?: PaymentMethod;

  @IsOptional()
  search?: string;

  @IsOptional()
  page?: number;

  @IsOptional()
  limit?: number;
}
