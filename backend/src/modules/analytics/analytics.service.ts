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
  creditCardTotal: number;
  creditCardTotalUSD: number;
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
    const incomeEnd = today < period.periodEnd ? today : period.periodEnd;

    const startStr = period.periodStart.toISOString().split('T')[0];
    const endStr = period.periodEnd.toISOString().split('T')[0];
    const todayStr = today.toISOString().split('T')[0];

    const [spentResult, todayResult, creditResult] = await Promise.all([
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
      this.expenseRepo
        .createQueryBuilder('e')
        .select('e.currency', 'currency')
        .addSelect('COALESCE(SUM(e.amount), 0)', 'total')
        .where('e.userId = :userId AND e.paymentMethod = :method AND e.date BETWEEN :start AND :end', {
          userId, method: 'card_credit', start: startStr, end: endStr,
        })
        .groupBy('e.currency')
        .getRawMany<{ currency: string; total: string }>(),
    ]);

    // Income basis for the current period:
    // 1) If an income has recorded receipts, use those real records.
    // 2) Otherwise, project from nextExpectedAt + cycle up to today.
    // 3) Legacy fallback for recurring incomes with no date configured.
    const recordRows = await this.incomeRecordRepo
      .createQueryBuilder('r')
      .select('r.incomeId', 'incomeId')
      .addSelect('COALESCE(SUM(r.amount), 0)', 'total')
      .where('r.userId = :userId AND r.receivedAt BETWEEN :start AND :end', {
        userId,
        start: startStr,
        end: incomeEnd.toISOString().split('T')[0],
      })
      .groupBy('r.incomeId')
      .getRawMany<{ incomeId: string; total: string }>();

    const recordsByIncome = new Map(
      recordRows.map((r) => [r.incomeId, parseFloat(r.total ?? '0')]),
    );

    const periodDays = this.daysBetween(period.periodStart, period.periodEnd) + 1;
    const cycleDaysMap: Record<string, number> = {
      [IncomeCycle.WEEKLY]: 7,
      [IncomeCycle.BIWEEKLY]: 14,
      [IncomeCycle.MONTHLY]: 30,
    };

    let totalIncome = 0;
    for (const src of incomeSources) {
      const recorded = recordsByIncome.get(src.id);
      if (recorded != null) {
        totalIncome += recorded;
        continue;
      }

      if (src.nextExpectedAt) {
        const expectedCount = this.countExpectedOccurrencesInRange(
          src,
          period.periodStart,
          incomeEnd,
        );
        totalIncome += Number(src.amount) * expectedCount;
        continue;
      }

      // Backward compatibility: recurring sources without configured date.
      if (src.cycle !== IncomeCycle.ONE_TIME) {
        const cycleDays = cycleDaysMap[src.cycle] ?? 30;
        const occurrences = Math.max(1, Math.floor(periodDays / cycleDays));
        totalIncome += Number(src.amount) * occurrences;
      }
    }

    const totalSpent = parseFloat(spentResult?.total ?? '0');
    const todaySpent = parseFloat(todayResult?.total ?? '0');
    const creditCardRows = creditResult as { currency: string; total: string }[];
    const creditCardTotal = parseFloat(
      creditCardRows.find(r => r.currency === 'HNL')?.total ?? '0'
    );
    const creditCardTotalUSD = parseFloat(
      creditCardRows.find(r => r.currency === 'USD')?.total ?? '0'
    );
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
      creditCardTotal,
      creditCardTotalUSD,
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

  async getPaymentMethodTrends(userId: string): Promise<{ month: string; cash: number; card_debit: number; card_credit: number; transfer: number; other: number }[]> {
    const today = new Date();
    // Build last 6 months (inclusive of current month)
    const months: { start: string; end: string; label: string }[] = [];
    for (let i = 5; i >= 0; i--) {
      const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
      const year = d.getFullYear();
      const month = d.getMonth(); // 0-based
      const start = `${year}-${String(month + 1).padStart(2, '0')}-01`;
      const lastDay = new Date(year, month + 1, 0).getDate();
      const end = `${year}-${String(month + 1).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
      const label = `${year}-${String(month + 1).padStart(2, '0')}`;
      months.push({ start, end, label });
    }

    const results = await Promise.all(
      months.map(async ({ start, end, label }) => {
        const raw = await this.expenseRepo
          .createQueryBuilder('e')
          .select('e.paymentMethod', 'method')
          .addSelect('COALESCE(SUM(e.amount), 0)', 'total')
          .where('e.userId = :userId AND e.date BETWEEN :start AND :end', { userId, start, end })
          .groupBy('e.paymentMethod')
          .getRawMany<{ method: string; total: string }>();

        const row: Record<string, number> = { cash: 0, card_debit: 0, card_credit: 0, transfer: 0, other: 0 };
        for (const r of raw) {
          const key = r.method in row ? r.method : 'other';
          row[key] = parseFloat(r.total ?? '0');
        }
        return { month: label, ...row } as { month: string; cash: number; card_debit: number; card_credit: number; transfer: number; other: number };
      }),
    );

    return results;
  }

  async getSimulation(    userId: string,
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
    * Derives pay period configuration for dashboard boundaries.
    * payCycle always comes from user settings so changing it has immediate effect.
    * If a primary income defines cut days, those can refine biweekly limits.
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

    const cycle: PayCycle = (user!.payCycle as PayCycle) ?? 'monthly';

    let payDay1 = user!.payDay1 ?? 15;
    let payDay2 = user!.payDay2 ?? 30;

    if (incomeSources.length > 0) {
      const primary = incomeSources.reduce((a, b) =>
        Number(a.amount) >= Number(b.amount) ? a : b,
      );
      if (typeof primary.payDay1 === 'number') payDay1 = primary.payDay1;
      if (typeof primary.payDay2 === 'number') payDay2 = primary.payDay2;
    }

    return {
      user: user!,
      cycle,
      payDay1,
      payDay2,
      incomeSources,
    };
  }

  private countExpectedOccurrencesInRange(income: Income, rangeStart: Date, rangeEnd: Date): number {
    if (!income.nextExpectedAt) return 0;

    const start = this.toDateOnly(rangeStart);
    const end = this.toDateOnly(rangeEnd);
    let cursor = this.toDateOnly(new Date(income.nextExpectedAt));

    if (cursor > end) {
      while (cursor > end) {
        cursor = this.shiftByCycle(cursor, income.cycle, -1);
      }
    }

    while (cursor < start) {
      cursor = this.shiftByCycle(cursor, income.cycle, 1);
    }

    let count = 0;
    let guard = 0;
    while (cursor <= end && guard < 500) {
      count += 1;
      cursor = this.shiftByCycle(cursor, income.cycle, 1);
      guard += 1;
    }

    return count;
  }

  private shiftByCycle(base: Date, cycle: IncomeCycle, direction: 1 | -1): Date {
    const d = this.toDateOnly(base);
    if (cycle === IncomeCycle.WEEKLY) {
      d.setDate(d.getDate() + 7 * direction);
      return d;
    }
    if (cycle === IncomeCycle.BIWEEKLY) {
      d.setDate(d.getDate() + 14 * direction);
      return d;
    }
    if (cycle === IncomeCycle.MONTHLY) {
      d.setMonth(d.getMonth() + direction);
      return d;
    }
    // one_time
    d.setDate(d.getDate() + 3650 * direction);
    return d;
  }

  private toDateOnly(date: Date): Date {
    const d = new Date(date);
    d.setHours(0, 0, 0, 0);
    return d;
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
