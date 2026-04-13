export type CategorizationConfidence = 'high' | 'medium' | 'low' | 'none';
export type CategorizationSource =
  | 'user_learning'
  | 'keyword_rule'
  | 'merchant_rule'
  | 'none';

export interface CategorizationResult {
  suggestedCategoryId: string | null;
  suggestedCategoryName: string | null;
  confidence: CategorizationConfidence;
  source: CategorizationSource;
  /** The keyword or merchant name that triggered the match — for debug/explainability */
  matchedKeyword: string | null;
  /** Name of the rule set that matched — for debug/explainability */
  matchedRule: string | null;
}

export const EMPTY_RESULT: CategorizationResult = {
  suggestedCategoryId: null,
  suggestedCategoryName: null,
  confidence: 'none',
  source: 'none',
  matchedKeyword: null,
  matchedRule: null,
};
