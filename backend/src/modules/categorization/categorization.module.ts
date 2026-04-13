import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserCategoryMapping } from './user-category-mapping.entity';
import { CategorizationAuditLog } from './categorization-audit-log.entity';
import { Category } from '../categories/category.entity';
import { CategorizationRulesService } from './categorization-rules.service';
import { CategorizationLearningService } from './categorization-learning.service';
import { ExpenseCategorizationService } from './expense-categorization.service';
import { CategorizationMetricsService } from './categorization-metrics.service';
import { CategorizationController } from './categorization.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserCategoryMapping,
      CategorizationAuditLog,
      Category,
    ]),
  ],
  controllers: [CategorizationController],
  providers: [
    CategorizationRulesService,
    CategorizationLearningService,
    ExpenseCategorizationService,
    CategorizationMetricsService,
  ],
  exports: [
    ExpenseCategorizationService,
    CategorizationLearningService,
  ],
})
export class CategorizationModule {}
