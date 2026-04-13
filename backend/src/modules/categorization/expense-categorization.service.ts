import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CategorizationAuditLog } from './categorization-audit-log.entity';
import { CategorizationRulesService } from './categorization-rules.service';
import { CategorizationLearningService } from './categorization-learning.service';
import {
  CategorizationResult,
  CategorizationConfidence,
  EMPTY_RESULT,
} from './interfaces/categorization-result.interface';
import { CATEGORIZATION_CONFIG } from './config/categorization.config';

@Injectable()
export class ExpenseCategorizationService {
  constructor(
    @InjectRepository(CategorizationAuditLog)
    private auditLogRepo: Repository<CategorizationAuditLog>,
    private rulesService: CategorizationRulesService,
    private learningService: CategorizationLearningService,
  ) {}

  // ── Main suggest method ──────────────────────────────────────────────────

  /**
   * Returns the best category suggestion for the given description.
   * Priority: user_learning > keyword_rule/merchant_rule > none
   */
  async suggest(userId: string, description: string): Promise<CategorizationResult> {
    if (!description?.trim()) return { ...EMPTY_RESULT };

    const normalized = this.rulesService.normalize(description);
    if (!normalized) return { ...EMPTY_RESULT };

    // 1. Check user's learned mappings (highest priority)
    const learned = await this.learningService.findUserMapping(userId, normalized);
    if (learned) return learned;

    // 2. Try global rules (merchants + keywords)
    const ruleResult = await this.rulesService.matchGlobal(normalized);
    if (ruleResult.confidence !== 'none') return ruleResult;

    return { ...EMPTY_RESULT };
  }

  // ── Decision helpers (driven by config, not hardcoded) ───────────────────

  /**
   * Returns true if the confidence is high enough to auto-assign
   * the category when creating an expense.
   */
  shouldAutoAssign(confidence: CategorizationConfidence): boolean {
    return confidence === CATEGORIZATION_CONFIG.autoAssignThreshold;
  }

  /**
   * Returns true if the confidence is high enough to surface
   * a suggestion chip in the UI (may or may not auto-assign).
   */
  shouldSuggest(confidence: CategorizationConfidence): boolean {
    if (confidence === 'none') return false;
    const levels: CategorizationConfidence[] = ['low', 'medium', 'high'];
    const threshold = CATEGORIZATION_CONFIG.suggestThreshold;
    return levels.indexOf(confidence) >= levels.indexOf(threshold);
  }

  // ── Audit log helpers ────────────────────────────────────────────────────

  async createAuditLog(
    userId: string,
    description: string | null,
    result: CategorizationResult,
    opts: { expenseId?: string; wasAutoAssigned?: boolean } = {},
  ): Promise<CategorizationAuditLog> {
    const log = this.auditLogRepo.create({
      userId,
      description,
      expenseId: opts.expenseId ?? null,
      suggestedCategoryId: result.suggestedCategoryId,
      finalCategoryId: result.suggestedCategoryId,
      confidence: result.confidence,
      source: result.source,
      matchedKeyword: result.matchedKeyword,
      wasAutoAssigned: opts.wasAutoAssigned ?? false,
      wasCorrected: false,
    });
    return this.auditLogRepo.save(log);
  }

  /**
   * Mark a previously created audit log as corrected and update the final category.
   * Called when user changes the category of an expense.
   */
  async markCorrected(
    userId: string,
    expenseId: string,
    finalCategoryId: string,
  ): Promise<void> {
    const log = await this.auditLogRepo.findOne({
      where: { userId, expenseId },
      order: { createdAt: 'DESC' },
    });
    if (!log) return;
    if (log.suggestedCategoryId === finalCategoryId) return; // not actually a correction
    log.wasCorrected = true;
    log.finalCategoryId = finalCategoryId;
    await this.auditLogRepo.save(log);
  }
}
