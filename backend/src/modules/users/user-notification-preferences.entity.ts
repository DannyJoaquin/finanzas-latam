import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity('user_notification_preferences')
export class UserNotificationPreferences {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid', unique: true })
  userId: string;

  @OneToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  // ── Push notifications ────────────────────────────────────────────────

  /** Push alerts when a budget reaches 50/80/100% */
  @Column({ name: 'push_budget_alerts', default: true })
  pushBudgetAlerts: boolean;

  /** Conditional daily reminder (only if no expenses logged today, racha at risk, etc.) */
  @Column({ name: 'push_daily_reminder', default: true })
  pushDailyReminder: boolean;

  /** Weekly spending summary every Monday */
  @Column({ name: 'push_weekly_summary', default: true })
  pushWeeklySummary: boolean;

  /** Push for HIGH/CRITICAL insights (anomaly, savings_opportunity, budget_warning) */
  @Column({ name: 'push_important_insights', default: true })
  pushImportantInsights: boolean;

  /** Push for CRITICAL financial risk insights (projection) */
  @Column({ name: 'push_critical_financial_alerts', default: true })
  pushCriticalFinancialAlerts: boolean;

  /** Push for motivational events (streak, achievement) — off by default to reduce noise */
  @Column({ name: 'push_motivation', default: false })
  pushMotivation: boolean;

  // ── Local device notifications (credit cards) ─────────────────────────

  /** Local alert 3 days before credit card cut-off date */
  @Column({ name: 'local_card_cutoff_alerts', default: true })
  localCardCutoffAlerts: boolean;

  /** Local reminder 5 days before payment due date */
  @Column({ name: 'local_card_due_5d', default: true })
  localCardDue5d: boolean;

  /** Local reminder 1 day before payment due date */
  @Column({ name: 'local_card_due_1d', default: true })
  localCardDue1d: boolean;

  /** Local reminder for pending balance after cut-off */
  @Column({ name: 'local_card_pending_balance', default: true })
  localCardPendingBalance: boolean;

  // ── In-app visibility ─────────────────────────────────────────────────

  /** Show savings opportunity insights in-app */
  @Column({ name: 'inapp_savings_opportunities', default: true })
  inappSavingsOpportunities: boolean;

  /** Show spending pattern insights in-app */
  @Column({ name: 'inapp_patterns', default: true })
  inappPatterns: boolean;

  /** Show streak and achievement insights in-app / notification center */
  @Column({ name: 'inapp_motivation', default: true })
  inappMotivation: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
