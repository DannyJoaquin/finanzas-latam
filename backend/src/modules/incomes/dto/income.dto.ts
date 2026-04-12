import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Length,
} from 'class-validator';
import { IncomeCycle, IncomeType } from '../income.entity';

export class CreateIncomeDto {
  @IsString()
  @Length(1, 150)
  sourceName: string;

  @IsNumber()
  @IsPositive()
  amount: number;

  @IsEnum(IncomeType)
  type: IncomeType;

  @IsEnum(IncomeCycle)
  cycle: IncomeCycle;

  @IsOptional()
  payDay1?: number;

  @IsOptional()
  payDay2?: number;

  @IsOptional()
  @IsDateString()
  nextExpectedAt?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpdateIncomeDto {
  @IsOptional()
  @IsString()
  @Length(1, 150)
  sourceName?: string;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsEnum(IncomeType)
  type?: IncomeType;

  @IsOptional()
  @IsEnum(IncomeCycle)
  cycle?: IncomeCycle;

  @IsOptional()
  payDay1?: number;

  @IsOptional()
  payDay2?: number;

  @IsOptional()
  @IsDateString()
  nextExpectedAt?: string;

  @IsOptional()
  isActive?: boolean;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class CreateIncomeRecordDto {
  @IsNumber()
  @IsPositive()
  amount: number;

  @IsDateString()
  receivedAt: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
