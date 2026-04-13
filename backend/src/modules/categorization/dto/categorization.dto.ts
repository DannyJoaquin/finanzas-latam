import { IsBoolean, IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class SuggestCategoryDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  description: string;
}

export class CategorizationFeedbackDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  description: string;

  @IsUUID()
  selectedCategoryId: string;

  /**
   * If true the user explicitly asked to "remember" this association,
   * which immediately confirms the mapping regardless of usageCount.
   */
  @IsOptional()
  @IsBoolean()
  remember?: boolean;
}
