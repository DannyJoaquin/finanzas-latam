import {
  Body, Controller, Delete, Get, HttpCode, HttpStatus,
  Param, ParseUUIDPipe, Post,
} from '@nestjs/common';
import { CashService, CashOperationDto, CreateCashAccountDto } from './cash.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('cash')
export class CashController {
  constructor(private cashService: CashService) {}

  @Get('accounts')
  findAccounts(@CurrentUser() user: User) {
    return this.cashService.findAccounts(user.id);
  }

  @Post('accounts')
  @HttpCode(HttpStatus.CREATED)
  createAccount(@CurrentUser() user: User, @Body() dto: CreateCashAccountDto) {
    return this.cashService.createAccount(user.id, dto);
  }

  @Delete('accounts/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteAccount(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.cashService.deleteAccount(user.id, id);
  }

  @Post('accounts/:id/deposit')
  deposit(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CashOperationDto,
  ) {
    return this.cashService.deposit(user.id, id, dto);
  }

  @Post('accounts/:id/withdraw')
  withdraw(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CashOperationDto,
  ) {
    return this.cashService.withdraw(user.id, id, dto);
  }

  @Get('accounts/:id/transactions')
  getTransactions(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.cashService.getTransactions(user.id, id);
  }
}
