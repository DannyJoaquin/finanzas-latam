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
    ]);
  }

  private async generateAnomalyInsights(userId: string): Promise<void> {
    const anomalies = await this.analyticsService.detectAnomalies(userId);
    for (const anomaly of anomalies) {
      const existing = await this.insightRepo.findOne({
        where: {
          userId,
          type: InsightType.ANOMALY,
          isDismissed: false,
        },
      });
      // Don't duplicate if there's already an active anomaly insight for this category
      if (existing) continue;

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
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      });
      await this.insightRepo.save(insight);
    }
  }

  private async generateProjectionInsights(userId: string): Promise<void> {
    const dashboard = await this.analyticsService.getDashboard(userId);
    if (dashboard.riskLevel !== 'red') return;

    const existing = await this.insightRepo.findOne({
      where: { userId, type: InsightType.PROJECTION, isDismissed: false },
    });
    if (existing) return;

    const insight = this.insightRepo.create({
      userId,
      type: InsightType.PROJECTION,
      priority: InsightPriority.CRITICAL,
      title: '⚠️ Tu dinero podría no alcanzar hasta la quincena',
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
      expiresAt: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000), // 3 days
    });
    await this.insightRepo.save(insight);
  }

  private async generateBudgetWarningInsights(userId: string): Promise<void> {
    // Handled by BudgetAlertsJob (hourly cron). No duplicate generation needed.
  }

  /** Detect day-of-week spending patterns over the last 4 weeks */
  private async generatePatternInsights(userId: string): Promise<void> {
    const existing = await this.insightRepo.findOne({
      where: { userId, type: InsightType.PATTERN, isDismissed: false },
    });
    if (existing) return;

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
      expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
    });
    await this.insightRepo.save(insight);
  }

  /** Find top spending category that represents >25% of income */
  private async generateSavingsOpportunityInsights(userId: string): Promise<void> {
    const existing = await this.insightRepo.findOne({
      where: { userId, type: InsightType.SAVINGS_OPPORTUNITY, isDismissed: false },
    });
    if (existing) return;

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
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });
    await this.insightRepo.save(insight);
  }
}
