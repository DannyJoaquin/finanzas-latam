import {
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';
import { CardNetwork } from '../credit-card.entity';

export class CreateCreditCardDto {
  @IsString()
  @IsNotEmpty()
  @Length(1, 100)
  name: string;

  @IsOptional()
  @IsEnum(CardNetwork)
  network?: CardNetwork;

  @IsInt()
  @Min(1)
  @Max(28)
  cutOffDay: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30)
  paymentDueDays?: number;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  creditLimit?: number;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  @Length(3, 3)
  limitCurrency?: string;
}

export class UpdateCreditCardDto {
  @IsOptional()
  @IsString()
  @Length(1, 100)
  name?: string;

  @IsOptional()
  @IsEnum(CardNetwork)
  network?: CardNetwork;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(28)
  cutOffDay?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30)
  paymentDueDays?: number;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  creditLimit?: number;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  @Length(3, 3)
  limitCurrency?: string;
}

export class RecordCardPaymentDto {
  @IsNumber()
  @IsPositive()
  amount: number;

  /** ISO date string (YYYY-MM-DD) */
  @IsDateString()
  paymentDate: string;

  /** Billing cycle start this payment covers (YYYY-MM-DD) */
  @IsDateString()
  cycleStart: string;

  /** Billing cycle end this payment covers (YYYY-MM-DD) */
  @IsDateString()
  cycleEnd: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
