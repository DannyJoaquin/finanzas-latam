import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';
import { BudgetPeriod } from '../budget.entity';

export class CreateBudgetDto {
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsString()
  @Length(1, 100)
  name?: string;

  @IsNumber()
  @IsPositive()
  amount: number;

  @IsEnum(BudgetPeriod)
  periodType: BudgetPeriod;

  @IsDateString()
  periodStart: string;

  @IsDateString()
  periodEnd: string;

  @IsOptional()
  @IsBoolean()
  isDynamic?: boolean;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(100)
  dynamicPct?: number;
}

export class UpdateBudgetDto {
  @IsOptional()
  @IsNumber()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsDateString()
  periodStart?: string;

  @IsOptional()
  @IsDateString()
  periodEnd?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
