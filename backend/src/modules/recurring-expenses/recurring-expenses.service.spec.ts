import { RecurringExpensesService } from './recurring-expenses.service';
import { RecurringExpense, RecurringFrequency } from './recurring-expense.entity';
import { PaymentMethod } from '../expenses/expense.entity';

const recurringRepoMock = () => ({
  find: jest.fn(),
  findOne: jest.fn(),
  create: jest.fn((value) => value),
  save: jest.fn((value) => Promise.resolve(value)),
  remove: jest.fn(),
});

const expenseRepoMock = () => ({ findOne: jest.fn() });
const categoryRepoMock = () => ({ findOne: jest.fn() });
const cashAccountRepoMock = () => ({ findOne: jest.fn() });
const creditCardRepoMock = () => ({ findOne: jest.fn() });

function makeRecurring(overrides: Partial<RecurringExpense> = {}): RecurringExpense {
  return {
    id: 'recurring-1',
    userId: 'user-1',
    name: 'Renta',
    amount: 6500,
    currency: 'HNL',
    categoryId: 'category-1',
    paymentMethod: PaymentMethod.CASH,
    cashAccountId: null,
    cashAccount: null,
    creditCardId: null,
    creditCard: null,
    notes: null,
    frequency: RecurringFrequency.MONTHLY,
    executionDay: 10,
    startDate: new Date('2026-08-10'),
    nextRunDate: new Date('2026-08-10'),
    lastGeneratedDate: null,
    isActive: true,
    pausedAt: null,
    lastGenerationAttemptAt: null,
    lastGenerationError: null,
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
    expenses: [],
    ...overrides,
  } as RecurringExpense;
}

describe('RecurringExpensesService', () => {
  let service: RecurringExpensesService;
  let recurringRepo: ReturnType<typeof recurringRepoMock>;
  let expenseRepo: ReturnType<typeof expenseRepoMock>;
  let categoryRepo: ReturnType<typeof categoryRepoMock>;
  let cashAccountRepo: ReturnType<typeof cashAccountRepoMock>;
  let creditCardRepo: ReturnType<typeof creditCardRepoMock>;
  let expensesService: { create: jest.Mock };

  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(Date.parse('2026-10-12T12:00:00.000Z'));
    recurringRepo = recurringRepoMock();
    expenseRepo = expenseRepoMock();
    categoryRepo = categoryRepoMock();
    cashAccountRepo = cashAccountRepoMock();
    creditCardRepo = creditCardRepoMock();
    expensesService = { create: jest.fn().mockResolvedValue({ id: 'expense-1' }) };
    categoryRepo.findOne.mockResolvedValue({ id: 'category-1', userId: null });
    expenseRepo.findOne.mockResolvedValue(null);
    service = new RecurringExpensesService(
      recurringRepo as any,
      expenseRepo as any,
      categoryRepo as any,
      cashAccountRepo as any,
      creditCardRepo as any,
      expensesService as any,
    );
  });

  afterEach(() => jest.useRealTimers());

  it('generates every overdue monthly occurrence and advances next date', async () => {
    const recurring = makeRecurring();
    recurringRepo.find.mockResolvedValue([recurring]);

    const processed = await service.processDueForUser('user-1');

    expect(processed).toBe(3);
    expect(expensesService.create).toHaveBeenCalledTimes(3);
    expect(expensesService.create.mock.calls.map((call) => call[1].date)).toEqual([
      '2026-08-10',
      '2026-09-10',
      '2026-10-10',
    ]);
    expect(recurring.lastGeneratedDate?.toISOString().slice(0, 10)).toBe('2026-10-10');
    expect(recurring.nextRunDate.toISOString().slice(0, 10)).toBe('2026-11-10');
  });

  it('does not create an occurrence that already exists', async () => {
    const recurring = makeRecurring({
      nextRunDate: new Date('2026-10-10'),
    });
    recurringRepo.find.mockResolvedValue([recurring]);
    expenseRepo.findOne.mockResolvedValue({ id: 'existing-expense' });

    const processed = await service.processDueForUser('user-1');

    expect(processed).toBe(0);
    expect(expensesService.create).not.toHaveBeenCalled();
    expect(recurring.nextRunDate.toISOString().slice(0, 10)).toBe('2026-11-10');
  });

  it('processes multiple recurring templates independently', async () => {
    const first = makeRecurring({
      nextRunDate: new Date('2026-10-10'),
    });
    const second = makeRecurring({
      id: 'recurring-2',
      name: 'Internet',
      categoryId: 'category-2',
      nextRunDate: new Date('2026-10-10'),
    });
    recurringRepo.find.mockResolvedValue([first, second]);

    const processed = await service.processAllDue();

    expect(processed).toBe(2);
    expect(expensesService.create).toHaveBeenCalledTimes(2);
    expect(expensesService.create.mock.calls.map((call) => call[2].recurringExpenseId)).toEqual([
      'recurring-1',
      'recurring-2',
    ]);
  });

  it('validates and stores the selected account and category', async () => {
    categoryRepo.findOne.mockResolvedValue({
      id: 'category-2',
      userId: 'user-1',
      isSystem: false,
    });
    cashAccountRepo.findOne.mockResolvedValue({ id: 'cash-1', userId: 'user-1' });

    await service.create('user-1', {
      name: 'Internet',
      amount: 550,
      currency: 'HNL',
      categoryId: 'category-2',
      paymentMethod: PaymentMethod.CASH,
      cashAccountId: 'cash-1',
      frequency: RecurringFrequency.MONTHLY,
      executionDay: 15,
      startDate: '2026-08-15',
    });

    expect(recurringRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        categoryId: 'category-2',
        cashAccountId: 'cash-1',
        paymentMethod: PaymentMethod.CASH,
      }),
    );
  });

  it('reactivates without backfilling the paused period', async () => {
    const recurring = makeRecurring({
      isActive: false,
      startDate: new Date('2026-08-10'),
      nextRunDate: new Date('2026-08-10'),
      pausedAt: new Date('2026-08-11'),
    });
    recurringRepo.findOne.mockResolvedValue(recurring);

    await service.update('user-1', recurring.id, { isActive: true });

    expect(recurring.isActive).toBe(true);
    expect(recurring.nextRunDate.toISOString().slice(0, 10)).toBe('2026-11-10');
    expect(recurring.pausedAt).toBeNull();
  });

  it('changes the template amount without changing already generated expenses', async () => {
    const recurring = makeRecurring({
      nextRunDate: new Date('2026-11-10'),
      lastGeneratedDate: new Date('2026-10-10'),
    });
    recurringRepo.findOne.mockResolvedValue(recurring);

    await service.update('user-1', recurring.id, { amount: 7000 });

    expect(recurring.amount).toBe(7000);
    expect(recurring.lastGeneratedDate?.toISOString().slice(0, 10)).toBe('2026-10-10');
    expect(recurring.nextRunDate.toISOString().slice(0, 10)).toBe('2026-11-10');
  });

  it('deletes only the recurring template', async () => {
    const recurring = makeRecurring();
    recurringRepo.findOne.mockResolvedValue(recurring);

    await service.remove('user-1', recurring.id);

    expect(recurringRepo.remove).toHaveBeenCalledWith(recurring);
  });
});
