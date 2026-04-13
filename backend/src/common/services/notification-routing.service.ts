import { Injectable } from '@nestjs/common';
import { InsightType, InsightPriority } from '../../modules/insights/insight.entity';
import { UserNotificationPreferences } from '../../modules/users/user-notification-preferences.entity';

/**
 * Cooldown hours per insight type to prevent repeated notifications
 * within a short window.
 */
export const INSIGHT_COOLDOWN_HOURS: Record<InsightType, number> = {
  [InsightType.ANOMALY]:             24,
  [InsightType.PROJECTION]:          12,
  [InsightType.BUDGET_WARNING]:       6,
  [InsightType.PATTERN]:             48,
  [InsightType.SAVINGS_OPPORTUNITY]: 48,
  [InsightType.STREAK]:              48,
  [InsightType.ACHIEVEMENT]:         72,
};

/**
 * Channel routing service — decides whether a given insight/event type
 * should be sent as a push notification or shown only in-app.
 *
 * Rules:
 * - CRITICAL insights always eligible for push (subject to user prefs)
 * - HIGH insights eligible for push except streak/achievement
 * - MEDIUM/LOW: in-app only
 * - Streak/Achievement: never push unless user explicitly enables push_motivation
 * - Savings opportunities / patterns: in-app only
 */
@Injectable()
export class NotificationRoutingService {
  /** Types considered "motivational" — separated from financial risk */
  private static readonly MOTIVATION_TYPES = new Set<InsightType>([
    InsightType.STREAK,
    InsightType.ACHIEVEMENT,
  ]);

  /** Types that can route through push when at HIGH/CRITICAL priority */
  private static readonly PUSH_ELIGIBLE_TYPES = new Set<InsightType>([
    InsightType.PROJECTION,
    InsightType.BUDGET_WARNING,
    InsightType.ANOMALY,
  ]);

  isMotivationType(type: InsightType): boolean {
    return NotificationRoutingService.MOTIVATION_TYPES.has(type);
  }

  /**
   * Whether this insight should be sent as a push notification,
   * given user preferences.
   */
  shouldSendPush(
    type: InsightType,
    priority: InsightPriority,
    prefs: UserNotificationPreferences,
  ): boolean {
    // Motivational events — only if user enabled push_motivation
    if (this.isMotivationType(type)) {
      return prefs.pushMotivation;
    }

    // Critical financial alerts (projection)
    if (type === InsightType.PROJECTION) {
      return prefs.pushCriticalFinancialAlerts;
    }

    // Must be in the push-eligible group and have HIGH/CRITICAL priority
    const priorityOk =
      priority === InsightPriority.CRITICAL || priority === InsightPriority.HIGH;
    const typeOk = NotificationRoutingService.PUSH_ELIGIBLE_TYPES.has(type);

    if (!typeOk || !priorityOk) return false;

    return prefs.pushImportantInsights;
  }

  /**
   * Whether this insight should be shown in the in-app notification center,
   * given user preferences.
   */
  shouldShowInApp(
    type: InsightType,
    prefs: UserNotificationPreferences,
  ): boolean {
    if (type === InsightType.SAVINGS_OPPORTUNITY) return prefs.inappSavingsOpportunities;
    if (type === InsightType.PATTERN) return prefs.inappPatterns;
    if (this.isMotivationType(type)) return prefs.inappMotivation;
    // All other types (anomaly, projection, budget_warning) always shown in-app
    return true;
  }

  /**
   * Scoring for push priority selection — highest score wins when only one
   * push slot is available per user per day.
   */
  pushPriorityScore(priority: InsightPriority): number {
    const scores: Record<InsightPriority, number> = {
      [InsightPriority.CRITICAL]: 4,
      [InsightPriority.HIGH]: 3,
      [InsightPriority.MEDIUM]: 2,
      [InsightPriority.LOW]: 1,
    };
    return scores[priority] ?? 1;
  }
}
