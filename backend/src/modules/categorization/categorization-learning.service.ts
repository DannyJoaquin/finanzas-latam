import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserCategoryMapping, MappingMatchType } from './user-category-mapping.entity';
import { Category } from '../categories/category.entity';
import {
  CategorizationResult,
  EMPTY_RESULT,
} from './interfaces/categorization-result.interface';
import { CATEGORIZATION_CONFIG } from './config/categorization.config';
import { CategorizationRulesService } from './categorization-rules.service';

export interface RecordFeedbackOptions {
  /** If true, immediately mark the mapping as confirmed regardless of usageCount */
  remember?: boolean;
}

@Injectable()
export class CategorizationLearningService {
  constructor(
    @InjectRepository(UserCategoryMapping)
    private mappingRepo: Repository<UserCategoryMapping>,
    @InjectRepository(Category)
    private categoryRepo: Repository<Category>,
    private rulesService: CategorizationRulesService,
  ) {}

  /**
   * Look up whether user has a confirmed mapping for this normalized text.
   * A mapping is active when isConfirmed = true OR usageCount >= min threshold.
   */
  async findUserMapping(
    userId: string,
    normalizedText: string,
  ): Promise<CategorizationResult | null> {
    const mapping = await this.mappingRepo
      .createQueryBuilder('m')
      .innerJoinAndSelect('m.category', 'cat')
      .where('m.userId = :userId', { userId })
      .andWhere('m.normalizedText = :text', { text: normalizedText })
      .andWhere(
        '(m.isConfirmed = true OR m.usageCount >= :minUsage)',
        { minUsage: CATEGORIZATION_CONFIG.learningMinUsageCount },
      )
      .orderBy('m.usageCount', 'DESC')
      .getOne();

    if (!mapping) return null;

    return {
      suggestedCategoryId: mapping.categoryId,
      suggestedCategoryName: mapping.category.name,
      confidence: 'high',
      source: 'user_learning',
      matchedKeyword: mapping.normalizedText,
      matchedRule: 'user_learned',
    };
  }

  /**
   * Record that the user associated this description with a category.
   * Upserts the mapping and increments usageCount.
   * Auto-confirms if the threshold is reached, or if `remember: true` is passed.
   */
  async recordFeedback(
    userId: string,
    originalText: string,
    categoryId: string,
    opts: RecordFeedbackOptions = {},
  ): Promise<void> {
    // Validate category exists
    const category = await this.categoryRepo.findOne({ where: { id: categoryId } });
    if (!category) return;

    const normalizedText = this.rulesService.normalize(originalText);
    if (!normalizedText) return;

    const existing = await this.mappingRepo.findOne({
      where: { userId, normalizedText },
    });

    if (existing) {
      existing.usageCount += 1;
      existing.categoryId = categoryId;
      existing.originalText = originalText;
      existing.lastUsedAt = new Date();
      existing.isConfirmed =
        existing.isConfirmed ||
        opts.remember === true ||
        existing.usageCount >= CATEGORIZATION_CONFIG.learningAutoConfirmThreshold;
      await this.mappingRepo.save(existing);
    } else {
      const mapping = this.mappingRepo.create({
        userId,
        normalizedText,
        originalText,
        categoryId,
        matchType: MappingMatchType.LEARNED,
        usageCount: 1,
        isConfirmed: opts.remember === true,
        lastUsedAt: new Date(),
      });
      await this.mappingRepo.save(mapping);
    }
  }
}
