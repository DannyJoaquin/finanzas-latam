import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Expense } from './expense.entity';
import { ExpensesController } from './expenses.controller';
import { ExpensesService } from './expenses.service';
import { Account } from '../accounts/account.entity';
import { AccountTransaction } from '../accounts/account-transaction.entity';
import { CategorizationModule } from '../categorization/categorization.module';
import { RulesModule } from '../rules/rules.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Expense, Account, AccountTransaction]),
    CategorizationModule,
    RulesModule,
  ],
  controllers: [ExpensesController],
  providers: [ExpensesService],
  exports: [ExpensesService],
})
export class ExpensesModule {}
