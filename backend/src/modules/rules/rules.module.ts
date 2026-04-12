import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Rule } from './rule.entity';
import { RulesService } from './rules.service';
import { RulesEvaluatorService } from './rules-evaluator.service';
import { RulesController } from './rules.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Rule])],
  controllers: [RulesController],
  providers: [RulesService, RulesEvaluatorService],
  exports: [RulesService, RulesEvaluatorService],
})
export class RulesModule {}
