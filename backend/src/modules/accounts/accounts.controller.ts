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
} from '@nestjs/common';
import {
  AccountsService,
  CashOperationDto,
  CreateAccountDto,
  UpdateAccountDto,
  UpdateCashTransactionDto,
} from './accounts.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

// Route stays at /cash for now — the mobile client still targets this path.
// It moves to /accounts in the phase that ships the mobile Accounts UI, so
// the backend and mobile route rename land in the same deploy.
@Controller('cash')
export class AccountsController {
  constructor(private accountsService: AccountsService) {}

  @Get('accounts')
  findAccounts(@CurrentUser() user: User) {
    return this.accountsService.findAccounts(user.id);
  }

  @Post('accounts')
  @HttpCode(HttpStatus.CREATED)
  createAccount(@CurrentUser() user: User, @Body() dto: CreateAccountDto) {
    return this.accountsService.createAccount(user.id, dto);
  }

  @Patch('accounts/:id')
  updateAccount(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAccountDto,
  ) {
    return this.accountsService.updateAccount(user.id, id, dto);
  }

  @Delete('accounts/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteAccount(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.accountsService.deleteAccount(user.id, id);
  }

  @Post('accounts/:id/deposit')
  deposit(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CashOperationDto,
  ) {
    return this.accountsService.deposit(user.id, id, dto);
  }

  @Post('accounts/:id/withdraw')
  withdraw(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CashOperationDto,
  ) {
    return this.accountsService.withdraw(user.id, id, dto);
  }

  @Get('accounts/:id/transactions')
  getTransactions(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.accountsService.getTransactions(user.id, id);
  }

  @Patch('accounts/:id/transactions/:transactionId')
  updateTransaction(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) accountId: string,
    @Param('transactionId', ParseUUIDPipe) transactionId: string,
    @Body() dto: UpdateCashTransactionDto,
  ) {
    return this.accountsService.updateTransaction(
      user.id,
      accountId,
      transactionId,
      dto,
    );
  }

  @Delete('accounts/:id/transactions/:transactionId')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteTransaction(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) accountId: string,
    @Param('transactionId', ParseUUIDPipe) transactionId: string,
  ) {
    return this.accountsService.deleteTransaction(
      user.id,
      accountId,
      transactionId,
    );
  }
}
