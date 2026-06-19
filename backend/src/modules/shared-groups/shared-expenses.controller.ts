import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import { SharedExpensesService } from './shared-expenses.service';
import { SettlementsService } from './settlements.service';
import {
  ApproveExpenseDto,
  CreateSharedExpenseDto,
  CreateSettlementDto,
  ImportExpenseRowDto,
  UpdateGroupSettingsDto,
  UpdateSharedExpenseDto,
} from './shared-groups.dto';

@Controller('shared-groups/:groupId')
export class SharedExpensesController {
  constructor(
    private readonly expensesService: SharedExpensesService,
    private readonly settlementsService: SettlementsService,
  ) {}

  // ── Shared Expenses ────────────────────────────────────────────────────────

  @Post('expenses')
  createExpense(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
    @Body() dto: CreateSharedExpenseDto,
  ) {
    return this.expensesService.createSharedExpense(user.id, groupId, dto);
  }

  @Get('expenses')
  getExpenses(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
  ) {
    return this.expensesService.getGroupExpenses(user.id, groupId);
  }

  @Patch('expenses/:expenseId')
  updateExpense(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
    @Param('expenseId', ParseUUIDPipe) expenseId: string,
    @Body() dto: UpdateSharedExpenseDto,
  ) {
    return this.expensesService.updateSharedExpense(user.id, groupId, expenseId, dto);
  }

  @Delete('expenses/:expenseId')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteExpense(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
    @Param('expenseId', ParseUUIDPipe) expenseId: string,
  ) {
    return this.expensesService.deleteSharedExpense(user.id, groupId, expenseId);
  }

  // ── Expense Approval ───────────────────────────────────────────────────────

  @Patch('expenses/:expenseId/approve')
  approveExpense(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
    @Param('expenseId', ParseUUIDPipe) expenseId: string,
    @Body() dto: ApproveExpenseDto,
  ) {
    return this.expensesService.approveExpense(user.id, groupId, expenseId, dto.note);
  }

  @Patch('expenses/:expenseId/reject')
  rejectExpense(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
    @Param('expenseId', ParseUUIDPipe) expenseId: string,
    @Body() dto: ApproveExpenseDto,
  ) {
    return this.expensesService.rejectExpense(user.id, groupId, expenseId, dto.note);
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  @Get('stats')
  getStats(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
  ) {
    return this.expensesService.getGroupStats(user.id, groupId);
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  @Get('export/csv')
  @Header('Content-Type', 'text/csv')
  @Header('Content-Disposition', 'attachment; filename="gastos.csv"')
  exportCsv(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
  ) {
    return this.expensesService.exportGroupExpenses(user.id, groupId);
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  @Post('import')
  importExpenses(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
    @Body() body: { rows: ImportExpenseRowDto[] },
  ) {
    return this.expensesService.importExpenses(user.id, groupId, body.rows);
  }

  // ── Group Settings ─────────────────────────────────────────────────────────

  @Get('settings')
  getSettings(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
  ) {
    return this.expensesService.getGroupSettings(user.id, groupId);
  }

  @Patch('settings')
  updateSettings(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
    @Body() dto: UpdateGroupSettingsDto,
  ) {
    return this.expensesService.updateGroupSettings(user.id, groupId, dto);
  }

  // ── Settlements ────────────────────────────────────────────────────────────

  @Post('settlements')
  createSettlement(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
    @Body() dto: CreateSettlementDto,
  ) {
    return this.settlementsService.createSettlement(user.id, groupId, dto);
  }

  @Get('settlements')
  getSettlements(
    @CurrentUser() user: User,
    @Param('groupId', ParseUUIDPipe) groupId: string,
  ) {
    return this.settlementsService.getGroupSettlements(user.id, groupId);
  }
}
