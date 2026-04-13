import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Expense } from './expense.entity';
import { ExpensesController } from './expenses.controller';
import { ExpensesService } from './expenses.service';
import { CashAccount } from '../cash/cash-account.entity';
import { CashTransaction } from '../cash/cash-transaction.entity';
import { CategorizationModule } from '../categorization/categorization.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Expense, CashAccount, CashTransaction]),
    CategorizationModule,
  ],
  controllers: [ExpensesController],
  providers: [ExpensesService],
  exports: [ExpensesService],
})
export class ExpensesModule {}
