import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Expense } from '../expenses/expense.entity';
import { Income, IncomeCycle } from '../incomes/income.entity';
import { IncomeRecord } from '../incomes/income-record.entity';
import { User } from '../users/user.entity';
import { getCurrentPeriod, daysRemainingInPeriod, PayCycle } from '../../common/utils/date-cycle.util';

export interface DashboardData {
  currentPeriod: { start: string; end: string };
  daysRemaining: number;
  safeDailySpend: number;
  riskLevel: 'green' | 'yellow' | 'red';
  totalIncomeThisPeriod: number;
  totalSpentThisPeriod: number;
  availableBalance: number;
  todaySpent: number;
  cashRunoutDate: string | null;
}

export interface SpendingTrend {
  categoryId: string;
  categoryName: string;
  categoryIcon: string;
  categoryColor: string;
  currentPeriodTotal: number;
  previousPeriodTotal: number;
  changePercent: number;
}

export interface AnomalyItem {
  categoryId: string;
  categoryName: string;
  currentWeekTotal: number;
  avgWeeklyTotal: number;
  zScore: number;
  severity: 'medium' | 'high';
}

@Injectable()
export class AnalyticsService {
  constructor(
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    @InjectRepository(Income)
    private incomeRepo: Repository<Income>,
    @InjectRepository(IncomeRecord)
    private incomeRecordRepo: Repository<IncomeRecord>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
  ) {}

  async getDashboard(userId: string): Promise<DashboardData> {
    const { cycle, payDay1, payDay2, incomeSources } = await this.getUserPeriodInfo(userId);
    const today = new Date();
    const period = getCurrentPeriod(today, cycle, payDay1, payDay2);
    const daysRemaining = daysRemainingInPeriod(today, period.periodEnd);

    const startStr = period.periodStart.toISOString().split('T')[0];
    const endStr = period.periodEnd.toISOString().split('T')[0];
    const todayStr = today.toISOString().split('T')[0];

    const [spentResult, todayResult] = await Promise.all([
      this.expenseRepo
        .createQueryBuilder('e')
        .select('COALESCE(SUM(e.amount), 0)', 'total')
        .where('e.userId = :userId AND e.date BETWEEN :start AND :end', {
          userId, start: startStr, end: endStr,
        })
        .getRawOne<{ total: string }>(),
      this.expenseRepo
        .createQueryBuilder('e')
        .select('COALESCE(SUM(e.amount), 0)', 'total')
        .where('e.userId = :userId AND e.date = :today', { userId, today: todayStr })
        .getRawOne<{ total: string }>(),
    ]);

    // Calculate expected income for this period based on each source's cycle.
    // periodDays = number of days in the period (inclusive).
    const periodDays = this.daysBetween(period.periodStart, period.periodEnd) + 1;
    const cycleDaysMap: Record<string, number> = {
      [IncomeCycle.WEEKLY]: 7,
      [IncomeCycle.BIWEEKLY]: 14,
      [IncomeCycle.MONTHLY]: 30,
    };
    let totalIncome = 0;
    for (const src of incomeSources) {
      const amount = Number(src.amount);
      if (src.cycle === IncomeCycle.ONE_TIME) {
        totalIncome += amount;
      } else {
        const cycleDays = cycleDaysMap[src.cycle] ?? 30;
        // How many times this income recurs in the period (at least 1)
        const occurrences = Math.max(1, Math.floor(periodDays / cycleDays));
        totalIncome += amount * occurrences;
      }
    }

    const totalSpent = parseFloat(spentResult?.total ?? '0');
    const todaySpent = parseFloat(todayResult?.total ?? '0');
    const available = totalIncome - totalSpent;
    const safeDailySpend = daysRemaining > 0 ? available / daysRemaining : 0;

    // Risk level: green < 70% spent, yellow 70–90%, red > 90%
    const spentRatio = totalIncome > 0 ? totalSpent / totalIncome : 1;
    const riskLevel: 'green' | 'yellow' | 'red' =
      spentRatio < 0.7 ? 'green' : spentRatio < 0.9 ? 'yellow' : 'red';

    // Cash-runout projection: at avg daily spend, when does available hit 0?
    const periodDaysElapsed = this.daysBetween(period.periodStart, today);
    const avgDailySpend = periodDaysElapsed > 0 ? totalSpent / periodDaysElapsed : totalSpent;
    let cashRunoutDate: string | null = null;
    if (avgDailySpend > 0 && available > 0) {
      const daysUntilZero = Math.floor(available / avgDailySpend);
      const runout = new Date(today);
      runout.setDate(today.getDate() + daysUntilZero);
      cashRunoutDate = runout.toISOString().split('T')[0];
    }

    return {
      currentPeriod: { start: startStr, end: endStr },
      daysRemaining,
      safeDailySpend: Math.max(0, safeDailySpend),
      riskLevel,
      totalIncomeThisPeriod: totalIncome,
      totalSpentThisPeriod: totalSpent,
      availableBalance: available,
      todaySpent,
      cashRunoutDate,
    };
  }

  async getSpendingTrends(userId: string): Promise<SpendingTrend[]> {
    const { cycle, payDay1, payDay2 } = await this.getUserPeriodInfo(userId);
    const today = new Date();
    const currentPeriod = getCurrentPeriod(today, cycle, payDay1, payDay2);

    // Previous period
    const prevEnd = new Date(currentPeriod.periodStart);
    prevEnd.setDate(prevEnd.getDate() - 1);
    const prevPeriod = getCurrentPeriod(prevEnd, cycle, payDay1, payDay2);

    const [current, previous] = await Promise.all([
      this.getSpendingByCategory(userId, currentPeriod.periodStart, currentPeriod.periodEnd),
      this.getSpendingByCategory(userId, prevPeriod.periodStart, prevPeriod.periodEnd),
    ]);

    const prevMap = new Map(previous.map((p) => [p.categoryId, p.total]));
    return current.map((c) => {
      const prevTotal = prevMap.get(c.categoryId) ?? 0;
      const changePercent = prevTotal > 0 ? ((c.total - prevTotal) / prevTotal) * 100 : 100;
      return {
        categoryId: c.categoryId,
        categoryName: c.categoryName,
        categoryIcon: c.categoryIcon,
        categoryColor: c.categoryColor,
        currentPeriodTotal: c.total,
        previousPeriodTotal: prevTotal,
        changePercent: Math.round(changePercent * 10) / 10,
      };
    });
  }

  async detectAnomalies(userId: string): Promise<AnomalyItem[]> {
    const today = new Date();
    const weekAgo = new Date(today);
    weekAgo.setDate(today.getDate() - 7);

    // Get current week totals per category
    const currentWeek = await this.getSpendingByCategory(userId, weekAgo, today);

    // Get average of the 4 prior weeks, per category
    const anomalies: AnomalyItem[] = [];
    for (const curr of currentWeek) {
      const weeklyTotals: number[] = [];
      for (let w = 1; w <= 4; w++) {
        const end = new Date(today);
        end.setDate(today.getDate() - w * 7);
        const start = new Date(end);
        start.setDate(end.getDate() - 7);
        const result = await this.expenseRepo
          .createQueryBuilder('e')
          .select('COALESCE(SUM(e.amount), 0)', 'total')
          .where('e.userId = :userId AND e.category_id = :catId AND e.date BETWEEN :start AND :end', {
            userId, catId: curr.categoryId, start: start.toISOString().split('T')[0],
            end: end.toISOString().split('T')[0],
          })
          .getRawOne<{ total: string }>();
        weeklyTotals.push(parseFloat(result?.total ?? '0'));
      }

      const avg = weeklyTotals.reduce((a, b) => a + b, 0) / weeklyTotals.length;
      if (avg === 0) continue;

      const variance = weeklyTotals.reduce((sum, v) => sum + Math.pow(v - avg, 2), 0) / weeklyTotals.length;
      const stdDev = Math.sqrt(variance);
      const zScore = stdDev > 0 ? (curr.total - avg) / stdDev : 0;

      if (zScore > 1.5) {
        anomalies.push({
          categoryId: curr.categoryId,
          categoryName: curr.categoryName,
          currentWeekTotal: curr.total,
          avgWeeklyTotal: Math.round(avg * 100) / 100,
          zScore: Math.round(zScore * 100) / 100,
          severity: zScore > 2.5 ? 'high' : 'medium',
        });
      }
    }
    return anomalies.sort((a, b) => b.zScore - a.zScore);
  }

  async getSimulation(
    userId: string,
    categoryId: string,
    reductionPct: number,
  ): Promise<{ currentMonthlyAvg: number; projectedSavings: number; annualSavings: number }> {
    const today = new Date();
    const ninetyDaysAgo = new Date(today);
    ninetyDaysAgo.setDate(today.getDate() - 90);

    const result = await this.expenseRepo
      .createQueryBuilder('e')
      .select('COALESCE(SUM(e.amount), 0)', 'total')
      .where('e.userId = :userId AND e.category_id = :catId AND e.date >= :start', {
        userId, catId: categoryId, start: ninetyDaysAgo.toISOString().split('T')[0],
      })
      .getRawOne<{ total: string }>();

    const total90 = parseFloat(result?.total ?? '0');
    const monthlyAvg = total90 / 3;
    const projectedSavings = monthlyAvg * (reductionPct / 100);
    return {
      currentMonthlyAvg: Math.round(monthlyAvg * 100) / 100,
      projectedSavings: Math.round(projectedSavings * 100) / 100,
      annualSavings: Math.round(projectedSavings * 12 * 100) / 100,
    };
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /**
   * Derives the pay period cycle and cut days from the user's income sources.
   * Uses the income source with the highest amount as the "primary" income.
   * Falls back to the user's configured payCycle if no incomes exist.
   */
  private async getUserPeriodInfo(userId: string): Promise<{
    user: User;
    cycle: PayCycle;
    payDay1: number;
    payDay2: number;
    incomeSources: Income[];
  }> {
    const [user, incomeSources] = await Promise.all([
      this.userRepo.findOne({ where: { id: userId } }),
      this.incomeRepo.find({ where: { userId, isActive: true } }),
    ]);

    let cycle: PayCycle = user!.payCycle as PayCycle;

    if (incomeSources.length > 0) {
      // Pick the income with the highest amount as the primary
      const primary = incomeSources.reduce((a, b) =>
        Number(a.amount) >= Number(b.amount) ? a : b,
      );
      const c = primary.cycle as string;
      // Map income cycle names to period PayCycle (one_time treated as monthly)
      const cycleMap: Record<string, PayCycle> = {
        weekly: 'weekly',
        biweekly: 'biweekly',
        monthly: 'monthly',
        one_time: 'monthly',
      };
      cycle = cycleMap[c] ?? 'monthly';
    }

    return {
      user: user!,
      cycle,
      payDay1: user!.payDay1 ?? 15,
      payDay2: user!.payDay2 ?? 30,
      incomeSources,
    };
  }

  private async getSpendingByCategory(
    userId: string,
    start: Date,
    end: Date,
  ): Promise<{ categoryId: string; categoryName: string; categoryIcon: string; categoryColor: string; total: number }[]> {
    const raw = await this.expenseRepo
      .createQueryBuilder('e')
      .select('cat.id', 'categoryId')
      .addSelect('cat.name', 'categoryName')
      .addSelect('COALESCE(cat.icon, \'more_horiz\')', 'categoryIcon')
      .addSelect('COALESCE(cat.color, \'#9E9E9E\')', 'categoryColor')
      .addSelect('SUM(e.amount)', 'total')
      .leftJoin('e.category', 'cat')
      .where('e.userId = :userId', { userId })
      .andWhere('e.date BETWEEN :start AND :end', {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0],
      })
      .groupBy('cat.id')
      .addGroupBy('cat.name')
      .addGroupBy('cat.icon')
      .addGroupBy('cat.color')
      .getRawMany<{ categoryId: string; categoryName: string; categoryIcon: string; categoryColor: string; total: string }>();

    return raw.map((r) => ({ ...r, total: parseFloat(r.total ?? '0') }));
  }

  private daysBetween(start: Date, end: Date): number {
    return Math.max(1, Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)));
  }
}
