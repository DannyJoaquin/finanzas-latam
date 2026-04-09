import { IsEnum, IsOptional, IsString, Length } from 'class-validator';
import { CategoryType } from '../category.entity';

export class CreateCategoryDto {
  @IsString()
  @Length(1, 100)
  name: string;

  @IsEnum(CategoryType)
  type: CategoryType;

  @IsOptional()
  @IsString()
  parentId?: string;

  @IsOptional()
  @IsString()
  icon?: string;

  @IsOptional()
  @IsString()
  @Length(7, 7)
  color?: string;
}

export class UpdateCategoryDto {
  @IsOptional()
  @IsString()
  @Length(1, 100)
  name?: string;

  @IsOptional()
  @IsString()
  icon?: string;

  @IsOptional()
  @IsString()
  @Length(7, 7)
  color?: string;
}
