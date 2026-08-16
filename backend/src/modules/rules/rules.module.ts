import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Rule } from './rule.entity';
import { RulesService } from './rules.service';
import { RulesEvaluatorService } from './rules-evaluator.service';
import { RulesController } from './rules.controller';
import { Expense } from '../expenses/expense.entity';
import { Insight } from '../insights/insight.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Rule, Expense, Insight])],
  controllers: [RulesController],
  providers: [RulesService, RulesEvaluatorService],
  exports: [RulesService, RulesEvaluatorService],
})
export class RulesModule {}
