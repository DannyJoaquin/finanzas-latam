import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Category } from '../categories/category.entity';
import { Account } from '../accounts/account.entity';
import { CreditCard } from '../credit-cards/credit-card.entity';
import { Expense } from '../expenses/expense.entity';
import { ExpensesModule } from '../expenses/expenses.module';
import { RecurringExpense } from './recurring-expense.entity';
import { RecurringExpensesController } from './recurring-expenses.controller';
import { RecurringExpensesService } from './recurring-expenses.service';
import { RecurringExpensesJob } from '../../jobs/recurring-expenses.job';

@Module({
  imports: [
    TypeOrmModule.forFeature([RecurringExpense, Expense, Category, Account, CreditCard]),
    ExpensesModule,
  ],
  controllers: [RecurringExpensesController],
  providers: [RecurringExpensesService, RecurringExpensesJob],
  exports: [RecurringExpensesService],
})
export class RecurringExpensesModule {}
