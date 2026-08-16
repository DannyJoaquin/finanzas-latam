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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import {
  CreateRecurringExpenseDto,
  UpdateRecurringExpenseDto,
} from './dto/recurring-expense.dto';
import { RecurringExpensesService } from './recurring-expenses.service';

@Controller('recurring-expenses')
export class RecurringExpensesController {
  constructor(private recurringExpensesService: RecurringExpensesService) {}

  @Get()
  findAll(@CurrentUser() user: User) {
    return this.recurringExpensesService.findAll(user.id);
  }

  @Get('upcoming')
  upcoming(@CurrentUser() user: User, @Query('limit') limit?: string) {
    return this.recurringExpensesService.upcoming(user.id, Number(limit) || 10);
  }

  @Get(':id')
  findOne(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.recurringExpensesService.findOne(user.id, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: User, @Body() dto: CreateRecurringExpenseDto) {
    return this.recurringExpensesService.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateRecurringExpenseDto,
  ) {
    return this.recurringExpensesService.update(user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.recurringExpensesService.remove(user.id, id);
  }
}
