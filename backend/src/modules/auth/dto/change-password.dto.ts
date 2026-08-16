import { IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsOptional()
  @IsString()
  @MinLength(8)
  currentPassword?: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(8)
  newPassword: string;
}
