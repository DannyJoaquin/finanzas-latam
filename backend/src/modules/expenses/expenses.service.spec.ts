import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ExpensesService } from './expenses.service';
import { Expense } from './expense.entity';

// Mock the queryBuilder chain
const createQbMock = (items: any[] = [], total = 0) => ({
  leftJoinAndSelect: jest.fn().mockReturnThis(),
  where: jest.fn().mockReturnThis(),
  andWhere: jest.fn().mockReturnThis(),
  orderBy: jest.fn().mockReturnThis(),
  addOrderBy: jest.fn().mockReturnThis(),
  skip: jest.fn().mockReturnThis(),
  take: jest.fn().mockReturnThis(),
  select: jest.fn().mockReturnThis(),
  addSelect: jest.fn().mockReturnThis(),
  leftJoin: jest.fn().mockReturnThis(),
  groupBy: jest.fn().mockReturnThis(),
  addGroupBy: jest.fn().mockReturnThis(),
  getManyAndCount: jest.fn().mockResolvedValue([items, total]),
  getRawMany: jest.fn().mockResolvedValue(items),
});

const mockExpenseRepo = () => ({
  createQueryBuilder: jest.fn(),
  findOne: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
  remove: jest.fn(),
});

describe('ExpensesService', () => {
  let service: ExpensesService;
  let repo: ReturnType<typeof mockExpenseRepo>;

  const userId = 'user-1';
  const expenseId = 'expense-1';

  const mockExpense = (): Expense =>
    ({
      id: expenseId,
      userId,
      amount: 250,
      description: 'Almuerzo',
      date: new Date('2026-04-01'),
      categoryId: 'cat-1',
    } as unknown as Expense);

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ExpensesService,
        { provide: getRepositoryToken(Expense), useFactory: mockExpenseRepo },
      ],
    }).compile();

    service = module.get<ExpensesService>(ExpensesService);
    repo = module.get(getRepositoryToken(Expense));
  });

  // ──────────────────────────────────────────────────────────────
  // findAll
  // ──────────────────────────────────────────────────────────────
  describe('findAll', () => {
    it('returns paginated items and meta', async () => {
      const expenses = [mockExpense()];
      const qb = createQbMock(expenses, 1);
      repo.createQueryBuilder.mockReturnValue(qb);

      const result = await service.findAll(userId, { page: 1, limit: 10 } as any);

      expect(result).toHaveProperty('items');
      expect(result).toHaveProperty('meta');
      expect(result.items).toEqual(expenses);
      expect(result.meta.total).toBe(1);
    });

    it('applies search filter via ILIKE', async () => {
      const qb = createQbMock([], 0);
      repo.createQueryBuilder.mockReturnValue(qb);

      await service.findAll(userId, { search: 'Almuerzo' } as any);

      expect(qb.andWhere).toHaveBeenCalledWith(
        'e.description ILIKE :search',
        { search: '%Almuerzo%' },
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // findOne
  // ──────────────────────────────────────────────────────────────
  describe('findOne', () => {
    it('returns expense with category and cashAccount relations', async () => {
      const expense = mockExpense();
      repo.findOne.mockResolvedValue(expense);

      const result = await service.findOne(userId, expenseId);

      expect(repo.findOne).toHaveBeenCalledWith({
        where: { id: expenseId, userId },
        relations: ['category', 'cashAccount'],
      });
      expect(result).toEqual(expense);
    });

    it('throws NotFoundException when expense not found', async () => {
      repo.findOne.mockResolvedValue(null);
      await expect(service.findOne(userId, 'bad-id')).rejects.toThrow(NotFoundException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // create
  // ──────────────────────────────────────────────────────────────
  describe('create', () => {
    it('creates expense with valid past date', async () => {
      repo.findOne.mockResolvedValue(null); // no duplicate
      const created = mockExpense();
      repo.create.mockReturnValue(created);
      repo.save.mockResolvedValue(created);

      const dto = {
        amount: 250,
        description: 'Almuerzo',
        date: '2026-04-01',
        categoryId: 'cat-1',
      } as any;

      const result = await service.create(userId, dto);
      expect(result).toEqual(created);
    });

    it('throws BadRequestException for future date', async () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 5);

      await expect(
        service.create(userId, { date: futureDate.toISOString().split('T')[0], amount: 100 } as any),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws ConflictException for duplicate within 5 seconds', async () => {
      repo.findOne.mockResolvedValue(mockExpense()); // simulate duplicate found

      await expect(
        service.create(userId, {
          amount: 250,
          description: 'Almuerzo',
          date: '2026-04-01',
          categoryId: 'cat-1',
        } as any),
      ).rejects.toThrow(ConflictException);
    });

    it('throws BadRequestException on foreign key violation (invalid category)', async () => {
      repo.findOne.mockResolvedValue(null);
      repo.create.mockReturnValue({});
      repo.save.mockRejectedValue({ code: '23503' });

      await expect(
        service.create(userId, { date: '2026-04-01', amount: 100 } as any),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // update
  // ──────────────────────────────────────────────────────────────
  describe('update', () => {
    it('updates fields and saves', async () => {
      const expense = mockExpense();
      repo.findOne.mockResolvedValue(expense);
      repo.save.mockResolvedValue({ ...expense, amount: 300 });

      const result = await service.update(userId, expenseId, { amount: 300 } as any);
      expect(result.amount).toBe(300);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // remove
  // ──────────────────────────────────────────────────────────────
  describe('remove', () => {
    it('removes expense when found', async () => {
      const expense = mockExpense();
      repo.findOne.mockResolvedValue(expense);
      repo.remove.mockResolvedValue(expense);

      await expect(service.remove(userId, expenseId)).resolves.not.toThrow();
      expect(repo.remove).toHaveBeenCalledWith(expense);
    });

    it('throws NotFoundException when expense not found', async () => {
      repo.findOne.mockResolvedValue(null);
      await expect(service.remove(userId, 'bad-id')).rejects.toThrow(NotFoundException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // getSummary
  // ──────────────────────────────────────────────────────────────
  describe('getSummary', () => {
    it('returns categories grouped with grandTotal', async () => {
      const rawRows = [
        { categoryId: 'cat-1', categoryName: 'Comida', total: '1500', count: '10' },
        { categoryId: 'cat-2', categoryName: 'Transporte', total: '500', count: '5' },
      ];
      const qb = createQbMock(rawRows);
      repo.createQueryBuilder.mockReturnValue(qb);

      const result = await service.getSummary(userId);

      expect(result).toHaveProperty('categories');
      expect(result).toHaveProperty('grandTotal');
      expect(result.grandTotal).toBe(2000);
    });

    it('returns grandTotal=0 when no expenses', async () => {
      const qb = createQbMock([]);
      repo.createQueryBuilder.mockReturnValue(qb);

      const result = await service.getSummary(userId);
      expect(result.grandTotal).toBe(0);
    });
  });
});
