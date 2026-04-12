import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Insight, InsightPriority, InsightType } from './insight.entity';
import { AnalyticsService } from '../analytics/analytics.service';
import { User } from '../users/user.entity';
import { Expense } from '../expenses/expense.entity';

@Injectable()
export class InsightsGeneratorService {
  constructor(
    @InjectRepository(Insight)
    private insightRepo: Repository<Insight>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    private analyticsService: AnalyticsService,
  ) {}

  /** Run for a single user — called by cron job or on-demand */
  async generateForUser(userId: string): Promise<void> {
    await Promise.all([
      this.generateAnomalyInsights(userId),
      this.generateBudgetWarningInsights(userId),
      this.generateProjectionInsights(userId),
      this.generatePatternInsights(userId),
      this.generateSavingsOpportunityInsights(userId),
      this.generateStreakInsights(userId),
      this.generateAchievements(userId),
    ]);
  }

  /**
   * Returns true if a non-dismissed, non-expired insight of the given type
   * already exists for this user. Used by all generators to avoid duplicates.
   */
  private async hasActiveInsight(userId: string, type: InsightType): Promise<boolean> {
    // Block regeneration if:
    //  a) a non-dismissed, non-expired insight of this type already exists, OR
    //  b) an insight of this type was generated within the last 4 hours (even if dismissed)
    //     — this prevents on-demand triggers from immediately undoing a "dismiss all".
    const cooldownDate = new Date(Date.now() - 4 * 60 * 60 * 1000);
    const count = await this.insightRepo
      .createQueryBuilder('i')
      .where('i.userId = :userId', { userId })
      .andWhere('i.type = :type', { type })
      .andWhere(
        '(i.isDismissed = false AND (i.expiresAt IS NULL OR i.expiresAt > NOW())) ' +
        'OR i.generatedAt > :cooldownDate',
        { cooldownDate },
      )
      .getCount();
    return count > 0;
  }

  /** 7-day expiry cap for all in-app indicators */
  private expiresInDays(days: number): Date {
    const capped = Math.min(days, 7);
    return new Date(Date.now() + capped * 24 * 60 * 60 * 1000);
  }

  private async generateAnomalyInsights(userId: string): Promise<void> {
    const anomalies = await this.analyticsService.detectAnomalies(userId);
    for (const anomaly of anomalies) {
      // Skip if a non-expired anomaly insight already exists (one at a time)
      if (await this.hasActiveInsight(userId, InsightType.ANOMALY)) continue;

      const multiplier = Math.round((anomaly.currentWeekTotal / (anomaly.avgWeeklyTotal || 1)) * 10) / 10;
      const insight = this.insightRepo.create({
        userId,
        type: InsightType.ANOMALY,
        priority: anomaly.severity === 'high' ? InsightPriority.HIGH : InsightPriority.MEDIUM,
        title: `Gasto inusual en ${anomaly.categoryName}`,
        body: `Esta semana gastaste ${multiplier}x más de lo normal en ${anomaly.categoryName}. ` +
          `Promedio semanal: L ${anomaly.avgWeeklyTotal.toFixed(0)}, esta semana: L ${anomaly.currentWeekTotal.toFixed(0)}.`,
        metadata: {
          categoryId: anomaly.categoryId,
          categoryName: anomaly.categoryName,
          currentWeekTotal: anomaly.currentWeekTotal,
          avgWeeklyTotal: anomaly.avgWeeklyTotal,
          multiplier,
        },
        expiresAt: this.expiresInDays(7),
      });
      await this.insightRepo.save(insight);
    }
  }

  private async generateProjectionInsights(userId: string): Promise<void> {
    const dashboard = await this.analyticsService.getDashboard(userId);

    // If situation improved, dismiss any stale warning so it clears from the UI
    if (dashboard.riskLevel !== 'red') {
      await this.insightRepo
        .createQueryBuilder()
        .update()
        .set({ isDismissed: true })
        .where('userId = :userId', { userId })
        .andWhere('type = :type', { type: InsightType.PROJECTION })
        .andWhere('isDismissed = false')
        .execute();
      return;
    }

    if (await this.hasActiveInsight(userId, InsightType.PROJECTION)) return;

    const insight = this.insightRepo.create({
      userId,
      type: InsightType.PROJECTION,
      priority: InsightPriority.CRITICAL,
      title: 'Tu dinero podría no alcanzar hasta la quincena',
      body: `A tu ritmo actual de gastos, podrías quedarte sin fondos antes del final del período. ` +
        `Gasto diario seguro: L ${dashboard.safeDailySpend.toFixed(0)}. ` +
        (dashboard.cashRunoutDate
          ? `Estimado de quiebre: ${dashboard.cashRunoutDate}.`
          : ''),
      metadata: {
        cashRunoutDate: dashboard.cashRunoutDate,
        safeDailySpend: dashboard.safeDailySpend,
        riskLevel: dashboard.riskLevel,
      },
      expiresAt: this.expiresInDays(3),
    });
    await this.insightRepo.save(insight);
  }

  private async generateBudgetWarningInsights(userId: string): Promise<void> {
    // Handled by BudgetAlertsJob (hourly cron). No duplicate generation needed.
  }

  /** Detect day-of-week spending patterns over the last 4 weeks */
  private async generatePatternInsights(userId: string): Promise<void> {
    if (await this.hasActiveInsight(userId, InsightType.PATTERN)) return;

    const fourWeeksAgo = new Date();
    fourWeeksAgo.setDate(fourWeeksAgo.getDate() - 28);

    const raw = await this.expenseRepo
      .createQueryBuilder('e')
      .select("EXTRACT(DOW FROM e.date::timestamp)", 'dow')
      .addSelect('COALESCE(SUM(e.amount), 0)', 'total')
      .addSelect('COUNT(*)', 'cnt')
      .where('e.userId = :userId AND e.date >= :start', {
        userId,
        start: fourWeeksAgo.toISOString().split('T')[0],
      })
      .groupBy('dow')
      .orderBy('total', 'DESC')
      .getRawMany<{ dow: string; total: string; cnt: string }>();

    if (raw.length < 3) return;

    const totals = raw.map((r) => parseFloat(r.total));
    const avg = totals.reduce((a, b) => a + b, 0) / totals.length;
    const top = raw[0];
    const topTotal = parseFloat(top.total);

    if (avg === 0 || topTotal < avg * 1.3) return;

    const dayNames = ['domingos', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábados'];
    const dayName = dayNames[parseInt(top.dow)] ?? 'ese día';
    const multiplier = Math.round((topTotal / avg) * 10) / 10;

    const insight = this.insightRepo.create({
      userId,
      type: InsightType.PATTERN,
      priority: InsightPriority.LOW,
      title: `Gastas más los ${dayName}`,
      body: `Tus gastos los ${dayName} son ${multiplier}x tu promedio semanal. ` +
        `Considera planificar con anticipación ese día.`,
      metadata: { dow: parseInt(top.dow), dayName, multiplier, avgTotal: Math.round(avg) },
      expiresAt: this.expiresInDays(7),
    });
    await this.insightRepo.save(insight);
  }

  /** Find top spending category that represents >25% of income */
  private async generateSavingsOpportunityInsights(userId: string): Promise<void> {
    if (await this.hasActiveInsight(userId, InsightType.SAVINGS_OPPORTUNITY)) return;

    const dashboard = await this.analyticsService.getDashboard(userId);
    if (dashboard.totalIncomeThisPeriod === 0) return;

    const trends = await this.analyticsService.getSpendingTrends(userId);
    if (trends.length === 0) return;

    const top = trends.reduce((a, b) =>
      a.currentPeriodTotal >= b.currentPeriodTotal ? a : b,
    );
    const pct = top.currentPeriodTotal / dashboard.totalIncomeThisPeriod;
    if (pct < 0.25) return;

    const simulation = await this.analyticsService.getSimulation(userId, top.categoryId, 20);
    const pctDisplay = Math.round(pct * 100);

    const insight = this.insightRepo.create({
      userId,
      type: InsightType.SAVINGS_OPPORTUNITY,
      priority: InsightPriority.MEDIUM,
      title: `${top.categoryName} consume el ${pctDisplay}% de tus ingresos`,
      body: `Reducir un 20% en ${top.categoryName} te ahorraría ` +
        `L ${simulation.projectedSavings.toFixed(0)}/mes — ` +
        `L ${simulation.annualSavings.toFixed(0)} al año.`,
      metadata: {
        categoryId: top.categoryId,
        categoryName: top.categoryName,
        pct: pctDisplay,
        projectedSavings: simulation.projectedSavings,
        annualSavings: simulation.annualSavings,
      },
      expiresAt: this.expiresInDays(7),
    });
    await this.insightRepo.save(insight);
  }

  // ── Streaks ──────────────────────────────────────────────────────────────

  /**
   * Counts consecutive days (ending today) where the user logged at least one expense.
   * Generates a STREAK insight for streaks of 3, 7, 14, and 30 days.
   */
  private async generateStreakInsights(userId: string): Promise<void> {
    const streak = await this._countConsecutiveDays(userId);
    if (streak < 3) return; // Minimum threshold

    // Only milestone streaks get an insight
    const milestones = [30, 14, 7, 3];
    const milestone = milestones.find((m) => streak >= m);
    if (!milestone) return;

    if (await this.hasActiveInsight(userId, InsightType.STREAK)) return;

    const messages: Record<number, { title: string; body: string }> = {
      3:  { title: '¡3 días seguidos! 🎯', body: 'Llevas 3 días consecutivos registrando tus gastos. ¡Sigue así!' },
      7:  { title: '¡Una semana completa! 🔥', body: '7 días seguidos registrando gastos. Tu hábito financiero se está formando.' },
      14: { title: '¡Dos semanas de racha! ⚡', body: '14 días consecutivos. Estás construyendo un excelente control financiero.' },
      30: { title: '¡Un mes completo! 🏆', body: '30 días de racha. Eres una persona con disciplina financiera ejemplar.' },
    };

    const msg = messages[milestone] ?? messages[3];
    const insight = this.insightRepo.create({
      userId,
      type: InsightType.STREAK,
      priority: milestone >= 14 ? InsightPriority.HIGH : InsightPriority.MEDIUM,
      title: msg.title,
      body: `${msg.body} Racha actual: ${streak} días.`,
      metadata: { streakDays: streak, milestone },
      expiresAt: this.expiresInDays(3),
    });
    await this.insightRepo.save(insight);
  }

  private async _countConsecutiveDays(userId: string): Promise<number> {
    // Get distinct days with at least one expense in the last 60 days
    const rows = await this.expenseRepo
      .createQueryBuilder('e')
      .select("TO_CHAR(e.date::timestamp, 'YYYY-MM-DD')", 'day')
      .where('e.userId = :userId', { userId })
      .andWhere("e.date >= NOW() - INTERVAL '60 days'")
      .groupBy('day')
      .orderBy('day', 'DESC')
      .getRawMany<{ day: string }>();

    if (rows.length === 0) return 0;

    const today = new Date().toISOString().slice(0, 10);
    // Allow today or yesterday as the start
    if (rows[0].day !== today) {
      const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
      if (rows[0].day !== yesterday) return 0;
    }

    let streak = 1;
    for (let i = 1; i < rows.length; i++) {
      const prev = new Date(rows[i - 1].day);
      const curr = new Date(rows[i].day);
      const diff = Math.round((prev.getTime() - curr.getTime()) / 86400000);
      if (diff === 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ── Achievements ─────────────────────────────────────────────────────────

  /**
   * Checks user milestones and creates ACHIEVEMENT insights when they are first reached.
   * Uses the insight itself as the persisted flag (no separate table needed).
   */
  private async generateAchievements(userId: string): Promise<void> {
    await Promise.all([
      this._checkFirstExpenseAchievement(userId),
      this._checkExpenseCountAchievement(userId, 10, '10 gastos registrados'),
      this._checkExpenseCountAchievement(userId, 50, '50 gastos registrados'),
      this._checkExpenseCountAchievement(userId, 100, '100 gastos registrados'),
    ]);
  }

  private async _hasAchievement(userId: string, key: string): Promise<boolean> {
    const count = await this.insightRepo
      .createQueryBuilder('i')
      .where('i.userId = :userId', { userId })
      .andWhere('i.type = :type', { type: InsightType.ACHIEVEMENT })
      .andWhere("i.metadata->>'key' = :key", { key })
      .getCount();
    return count > 0;
  }

  private async _checkFirstExpenseAchievement(userId: string): Promise<void> {
    const key = 'first_expense';
    if (await this._hasAchievement(userId, key)) return;

    const count = await this.expenseRepo.count({ where: { userId } });
    if (count < 1) return;

    await this.insightRepo.save(this.insightRepo.create({
      userId,
      type: InsightType.ACHIEVEMENT,
      priority: InsightPriority.LOW,
      title: '¡Primer gasto registrado! 🎉',
      body: 'Has registrado tu primer gasto. ¡Bienvenido a un mejor control financiero!',
      metadata: { key },
      expiresAt: this.expiresInDays(7),
    }));
  }

  private async _checkExpenseCountAchievement(userId: string, threshold: number, label: string): Promise<void> {
    const key = `expense_count_${threshold}`;
    if (await this._hasAchievement(userId, key)) return;

    const count = await this.expenseRepo.count({ where: { userId } });
    if (count < threshold) return;

    await this.insightRepo.save(this.insightRepo.create({
      userId,
      type: InsightType.ACHIEVEMENT,
      priority: InsightPriority.MEDIUM,
      title: `¡Logro: ${label}! 🏅`,
      body: `Llevas ${count} gastos registrados. Cada registro es un paso hacia mejor salud financiera.`,
      metadata: { key, threshold, actual: count },
      expiresAt: this.expiresInDays(7),
    }));
  }
}
