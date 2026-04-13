import { CategorizationConfidence } from '../interfaces/categorization-result.interface';

export interface CategorizationConfig {
  /**
   * Minimum confidence level to auto-assign category when creating an expense
   * without a provided categoryId.
   */
  autoAssignThreshold: CategorizationConfidence;

  /**
   * Minimum confidence level to surface a suggestion to the user (chip in UI).
   * Must be lower or equal priority than autoAssignThreshold.
   */
  suggestThreshold: CategorizationConfidence;

  /**
   * Minimum number of usages before a learned mapping becomes active
   * (without explicit user confirmation via "remember").
   */
  learningMinUsageCount: number;

  /**
   * Number of usages after which a learned mapping is auto-confirmed,
   * regardless of explicit user confirmation.
   */
  learningAutoConfirmThreshold: number;
}

export const CATEGORIZATION_CONFIG: CategorizationConfig = {
  autoAssignThreshold: 'high',
  suggestThreshold: 'medium',
  learningMinUsageCount: 2,
  learningAutoConfirmThreshold: 3,
};
