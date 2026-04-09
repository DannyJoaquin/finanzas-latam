import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Rule } from './rule.entity';
import { RulesService } from './rules.service';
import { RulesEvaluatorService } from './rules-evaluator.service';

@Module({
  imports: [TypeOrmModule.forFeature([Rule])],
  providers: [RulesService, RulesEvaluatorService],
  exports: [RulesService, RulesEvaluatorService],
})
export class RulesModule {}
