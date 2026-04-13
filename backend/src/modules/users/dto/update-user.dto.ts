import { IsEnum, IsOptional, IsString, Length } from 'class-validator';
import { ExperienceMode, PayCycle } from '../user.entity';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @Length(1, 150)
  fullName?: string;

  @IsOptional()
  @IsString()
  @Length(1, 20)
  phone?: string;

  @IsOptional()
  @IsEnum(PayCycle)
  payCycle?: PayCycle;

  @IsOptional()
  payDay1?: number;

  @IsOptional()
  payDay2?: number;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @IsOptional()
  @IsString()
  @Length(2, 2)
  countryCode?: string;

  @IsOptional()
  fcmToken?: string;

  @IsOptional()
  @IsEnum(ExperienceMode)
  experienceMode?: ExperienceMode;
}
