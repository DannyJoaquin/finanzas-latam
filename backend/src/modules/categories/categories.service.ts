import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { Category, CategoryType } from './category.entity';
import { CreateCategoryDto, UpdateCategoryDto } from './dto/category.dto';

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(Category)
    private categoryRepo: Repository<Category>,
  ) {}

  /** Returns system categories + user's custom categories, with children nested */
  async findAll(userId: string): Promise<Category[]> {
    const categories = await this.categoryRepo.find({
      where: [
        { isSystem: true, parentId: IsNull() as unknown as string },
        { userId, parentId: IsNull() as unknown as string },
      ],
      relations: ['children'],
      order: { sortOrder: 'ASC', name: 'ASC' },
    });
    return categories;
  }

  async create(userId: string, dto: CreateCategoryDto): Promise<Category> {
    const category = this.categoryRepo.create({
      ...dto,
      userId,
      isSystem: false,
    });
    return this.categoryRepo.save(category);
  }

  async update(userId: string, id: string, dto: UpdateCategoryDto): Promise<Category> {
    const category = await this.categoryRepo.findOne({ where: { id } });
    if (!category) throw new NotFoundException('Category not found');
    if (category.isSystem) throw new BadRequestException('Cannot modify system categories');
    if (category.userId !== userId) throw new NotFoundException('Category not found');

    Object.assign(category, dto);
    return this.categoryRepo.save(category);
  }

  async delete(userId: string, id: string): Promise<void> {
    const category = await this.categoryRepo.findOne({
      where: { id },
      relations: ['expenses'],
    });
    if (!category) throw new NotFoundException('Category not found');
    if (category.isSystem) throw new BadRequestException('Cannot delete system categories');
    if (category.userId !== userId) throw new NotFoundException('Category not found');
    if (category.expenses?.length > 0) {
      throw new BadRequestException('Cannot delete category with existing expenses');
    }
    await this.categoryRepo.remove(category);
  }
}
