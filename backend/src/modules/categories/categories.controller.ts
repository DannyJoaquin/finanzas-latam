import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto, UpdateCategoryDto } from './dto/category.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('categories')
export class CategoriesController {
  constructor(private categoriesService: CategoriesService) {}

  @Get()
  findAll(@CurrentUser() user: User) {
    return this.categoriesService.findAll(user.id);
  }

  @Post()
  create(@CurrentUser() user: User, @Body() dto: CreateCategoryDto) {
    return this.categoriesService.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCategoryDto,
  ) {
    return this.categoriesService.update(user.id, id, dto);
  }

  @Delete(':id')
  delete(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.categoriesService.delete(user.id, id);
  }
}
