import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { IncomesService } from './incomes.service';
import { Income } from './income.entity';
import { IncomeRecord } from './income-record.entity';

const mockIncomeRepo = () => ({
  find: jest.fn(),
  findOne: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
});

const mockRecordRepo = () => ({
  find: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
});

describe('IncomesService', () => {
  let service: IncomesService;
  let incomeRepo: ReturnType<typeof mockIncomeRepo>;
  let recordRepo: ReturnType<typeof mockRecordRepo>;

  const userId = 'user-1';
  const incomeId = 'income-1';

  const mockIncome = (): Income =>
    ({
      id: incomeId,
      userId,
      name: 'Salario',
      amount: 20000,
      cycle: 'monthly',
      isActive: true,
      records: [],
    } as unknown as Income);

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        IncomesService,
        { provide: getRepositoryToken(Income), useFactory: mockIncomeRepo },
        { provide: getRepositoryToken(IncomeRecord), useFactory: mockRecordRepo },
      ],
    }).compile();

    service = module.get<IncomesService>(IncomesService);
    incomeRepo = module.get(getRepositoryToken(Income));
    recordRepo = module.get(getRepositoryToken(IncomeRecord));
  });

  // ──────────────────────────────────────────────────────────────
  // findAll
  // ──────────────────────────────────────────────────────────────
  describe('findAll', () => {
    it('returns only active incomes ordered by createdAt DESC', async () => {
      const incomes = [mockIncome()];
      incomeRepo.find.mockResolvedValue(incomes);

      const result = await service.findAll(userId);

      expect(incomeRepo.find).toHaveBeenCalledWith({
        where: { userId, isActive: true },
        order: { createdAt: 'DESC' },
      });
      expect(result).toEqual(incomes);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // findOne
  // ──────────────────────────────────────────────────────────────
  describe('findOne', () => {
    it('returns income with records relation', async () => {
      const income = mockIncome();
      incomeRepo.findOne.mockResolvedValue(income);

      const result = await service.findOne(userId, incomeId);

      expect(incomeRepo.findOne).toHaveBeenCalledWith({
        where: { id: incomeId, userId },
        relations: ['records'],
      });
      expect(result).toEqual(income);
    });

    it('throws NotFoundException when income not found', async () => {
      incomeRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(userId, 'bad-id')).rejects.toThrow(NotFoundException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // create
  // ──────────────────────────────────────────────────────────────
  describe('create', () => {
    it('creates income with userId', async () => {
      const dto = { name: 'Freelance', amount: 5000, cycle: 'monthly' } as any;
      const created = { ...mockIncome(), name: 'Freelance', amount: 5000 };
      incomeRepo.create.mockReturnValue(created);
      incomeRepo.save.mockResolvedValue(created);

      const result = await service.create(userId, dto);

      expect(incomeRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ userId }),
      );
      expect(result).toEqual(created);
    });

    it('converts nextExpectedAt string to Date', async () => {
      const dto = { name: 'Bono', amount: 2000, nextExpectedAt: '2026-05-01' } as any;
      incomeRepo.create.mockReturnValue({});
      incomeRepo.save.mockResolvedValue({});

      await service.create(userId, dto);

      expect(incomeRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ nextExpectedAt: new Date('2026-05-01') }),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // remove (soft delete)
  // ──────────────────────────────────────────────────────────────
  describe('remove', () => {
    it('soft-deletes by setting isActive=false', async () => {
      const income = mockIncome();
      incomeRepo.findOne.mockResolvedValue(income);
      incomeRepo.save.mockResolvedValue({ ...income, isActive: false });

      await service.remove(userId, incomeId);

      expect(income.isActive).toBe(false);
      expect(incomeRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ isActive: false }),
      );
    });

    it('throws NotFoundException when income not found', async () => {
      incomeRepo.findOne.mockResolvedValue(null);
      await expect(service.remove(userId, 'bad-id')).rejects.toThrow(NotFoundException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // addRecord
  // ──────────────────────────────────────────────────────────────
  describe('addRecord', () => {
    it('creates a record and validates ownership', async () => {
      incomeRepo.findOne.mockResolvedValue(mockIncome()); // ownership check
      const record = { id: 'rec-1', amount: 20000 };
      recordRepo.create.mockReturnValue(record);
      recordRepo.save.mockResolvedValue(record);

      const dto = { amount: 20000 } as any;
      const result = await service.addRecord(userId, incomeId, dto);

      expect(incomeRepo.findOne).toHaveBeenCalled(); // ownership verified
      expect(recordRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ incomeId, userId }),
      );
      expect(result).toEqual(record);
    });

    it('throws NotFoundException when income not found during addRecord', async () => {
      incomeRepo.findOne.mockResolvedValue(null);
      await expect(
        service.addRecord(userId, 'bad-id', { amount: 100 } as any),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // getRecords
  // ──────────────────────────────────────────────────────────────
  describe('getRecords', () => {
    it('returns records ordered by receivedAt DESC', async () => {
      const records = [{ id: 'rec-1' }];
      recordRepo.find.mockResolvedValue(records);

      const result = await service.getRecords(userId, incomeId);

      expect(recordRepo.find).toHaveBeenCalledWith({
        where: { incomeId, userId },
        order: { receivedAt: 'DESC' },
      });
      expect(result).toEqual(records);
    });
  });
});
