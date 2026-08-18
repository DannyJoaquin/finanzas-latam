import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AnalyticsService } from './analytics.service';
import { Expense } from '../expenses/expense.entity';
import { Income, IncomeCycle, IncomeType } from '../incomes/income.entity';
import { IncomeRecord } from '../incomes/income-record.entity';
import { User } from '../users/user.entity';

// Query-builder rows keyed by currency, resolved per-call in call order:
// [spentResult, todayResult, creditResult].
function mockExpenseRepo(queryResults: { currency: string; total: string }[][]) {
  let call = 0;
  return {
    createQueryBuilder: jest.fn(() => {
      const rows = queryResults[Math.min(call, queryResults.length - 1)];
      call += 1;
      const qb: any = {
        select: jest.fn(() => qb),
        addSelect: jest.fn(() => qb),
        where: jest.fn(() => qb),
        groupBy: jest.fn(() => qb),
        getRawMany: jest.fn(() => Promise.resolve(rows)),
      };
      return qb;
    }),
  };
}

function mockIncomeRecordRepo() {
  const qb: any = {
    select: jest.fn(() => qb),
    addSelect: jest.fn(() => qb),
    where: jest.fn(() => qb),
    groupBy: jest.fn(() => qb),
    getRawMany: jest.fn(() => Promise.resolve([])),
  };
  return { createQueryBuilder: jest.fn(() => qb) };
}

describe('AnalyticsService.getDashboard — currency discipline', () => {
  let service: AnalyticsService;
  let expenseRepo: ReturnType<typeof mockExpenseRepo>;
  let incomeRepo: { find: jest.Mock; findOne: jest.Mock };
  let userRepo: { findOne: jest.Mock };

  const userId = 'user-1';

  beforeEach(async () => {
    expenseRepo = mockExpenseRepo([
      // spentResult: 1200 HNL + 50 USD spent this period
      [{ currency: 'HNL', total: '1200' }, { currency: 'USD', total: '50' }],
      // todayResult: 0
      [],
      // creditResult: 0
      [],
    ]);
    incomeRepo = { find: jest.fn(), findOne: jest.fn() };
    userRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: userId,
        payCycle: 'monthly',
        payDay1: 15,
        payDay2: 30,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AnalyticsService,
        { provide: getRepositoryToken(Expense), useValue: expenseRepo },
        { provide: getRepositoryToken(Income), useValue: incomeRepo },
        { provide: getRepositoryToken(IncomeRecord), useValue: mockIncomeRecordRepo() },
        { provide: getRepositoryToken(User), useValue: userRepo },
      ],
    }).compile();

    service = module.get<AnalyticsService>(AnalyticsService);
  });

  it('never mixes a USD income into the HNL total, and vice versa', async () => {
    incomeRepo.find.mockResolvedValue([
      {
        id: 'income-hnl',
        userId,
        amount: 20000,
        currency: 'HNL',
        cycle: IncomeCycle.MONTHLY,
        type: IncomeType.SALARY,
        isActive: true,
        nextExpectedAt: null,
      },
      {
        id: 'income-usd',
        userId,
        amount: 500,
        currency: 'USD',
        cycle: IncomeCycle.MONTHLY,
        type: IncomeType.FREELANCE,
        isActive: true,
        nextExpectedAt: null,
      },
    ] as unknown as Income[]);

    const dashboard = await service.getDashboard(userId);

    // The USD income (500) must never be added into the HNL total, and the
    // HNL income (20000) must never leak into the USD total.
    expect(dashboard.totalIncomeThisPeriod).toBe(20000);
    expect(dashboard.totalIncomeThisPeriodUSD).toBe(500);

    // Spend is likewise kept separate: 1200 HNL and 50 USD.
    expect(dashboard.totalSpentThisPeriod).toBe(1200);
    expect(dashboard.totalSpentThisPeriodUSD).toBe(50);

    // Available balance per currency must never be a cross-currency figure —
    // e.g. NOT (20000 + 500) - (1200 + 50).
    expect(dashboard.availableBalance).toBe(20000 - 1200);
    expect(dashboard.availableBalanceUSD).toBe(500 - 50);
  });

  it('keeps safeDailySpend split per currency', async () => {
    incomeRepo.find.mockResolvedValue([
      {
        id: 'income-usd',
        userId,
        amount: 1000,
        currency: 'USD',
        cycle: IncomeCycle.MONTHLY,
        type: IncomeType.FREELANCE,
        isActive: true,
        nextExpectedAt: null,
      },
    ] as unknown as Income[]);

    const dashboard = await service.getDashboard(userId);

    // No HNL income exists — HNL available must be purely negative from the
    // 1200 HNL spend, and must not be offset by the USD income.
    expect(dashboard.totalIncomeThisPeriod).toBe(0);
    expect(dashboard.availableBalance).toBe(0 - 1200);
    expect(dashboard.totalIncomeThisPeriodUSD).toBe(1000);
    expect(dashboard.availableBalanceUSD).toBe(1000 - 50);
  });
});
