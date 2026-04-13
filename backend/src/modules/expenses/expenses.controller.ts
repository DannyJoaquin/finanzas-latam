import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ExpensesService } from './expenses.service';
import { CreateExpenseDto, FilterExpensesDto, UpdateExpenseDto } from './dto/expense.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import { ExpenseCategorizationService } from '../categorization/expense-categorization.service';
import { SuggestCategoryDto } from '../categorization/dto/categorization.dto';

@Controller('expenses')
export class ExpensesController {
  constructor(
    private expensesService: ExpensesService,
    private categorizationService: ExpenseCategorizationService,
  ) {}

  @Get()
  findAll(@CurrentUser() user: User, @Query() filters: FilterExpensesDto) {
    return this.expensesService.findAll(user.id, filters);
  }

  @Get('summary')
  getSummary(
    @CurrentUser() user: User,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.expensesService.getSummary(user.id, startDate, endDate);
  }

  /**
   * POST /expenses/suggest-category
   * Returns a category suggestion for the given description.
   * Does not persist anything — pure read.
   */
  @Post('suggest-category')
  @HttpCode(HttpStatus.OK)
  suggestCategory(
    @CurrentUser() user: User,
    @Body() dto: SuggestCategoryDto,
  ) {
    return this.categorizationService.suggest(user.id, dto.description);
  }

  @Get('summary-by-method')
  getSummaryByMethod(
    @CurrentUser() user: User,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.expensesService.getSummaryByMethod(user.id, startDate, endDate);
  }

  @Get(':id')
  findOne(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.expensesService.findOne(user.id, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: User, @Body() dto: CreateExpenseDto) {
    return this.expensesService.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateExpenseDto,
  ) {
    return this.expensesService.update(user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.expensesService.remove(user.id, id);
  }
}
