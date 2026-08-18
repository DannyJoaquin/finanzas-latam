import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  AccountsService,
  CreateAccountDto,
  CashOperationDto,
} from './accounts.service';
import { Account } from './account.entity';
import {
  AccountTransaction,
  AccountTxType,
} from './account-transaction.entity';

const mockAccountRepo = () => ({
  find: jest.fn(),
  findOne: jest.fn(),
  count: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
  delete: jest.fn(),
  remove: jest.fn(),
});

const mockTxRepo = () => ({
  find: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
});

describe('AccountsService', () => {
  let service: AccountsService;
  let accountRepo: ReturnType<typeof mockAccountRepo>;
  let txRepo: ReturnType<typeof mockTxRepo>;

  const userId = 'user-1';
  const accountId = 'account-1';

  const mockAccount = (): Account =>
    ({
      id: accountId,
      userId,
      name: 'Mi cartera',
      currency: 'HNL',
      balance: 100,
      isDefault: true,
      isLocked: false,
      sortOrder: 0,
    }) as Account;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AccountsService,
        { provide: getRepositoryToken(Account), useFactory: mockAccountRepo },
        {
          provide: getRepositoryToken(AccountTransaction),
          useFactory: mockTxRepo,
        },
      ],
    }).compile();

    service = module.get<AccountsService>(AccountsService);
    accountRepo = module.get(getRepositoryToken(Account));
    txRepo = module.get(getRepositoryToken(AccountTransaction));
  });

  // ──────────────────────────────────────────────────────────────
  // findAccounts
  // ──────────────────────────────────────────────────────────────
  describe('findAccounts', () => {
    it('returns accounts ordered by isDefault DESC, sortOrder ASC', async () => {
      const accounts = [mockAccount()];
      accountRepo.find.mockResolvedValue(accounts);

      const result = await service.findAccounts(userId);

      expect(accountRepo.find).toHaveBeenCalledWith({
        where: { userId },
        order: { isDefault: 'DESC', sortOrder: 'ASC' },
      });
      expect(result).toEqual(accounts);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // findAccount
  // ──────────────────────────────────────────────────────────────
  describe('findAccount', () => {
    it('returns account when found', async () => {
      const acc = mockAccount();
      accountRepo.findOne.mockResolvedValue(acc);

      const result = await service.findAccount(userId, accountId);
      expect(result).toEqual(acc);
    });

    it('throws NotFoundException when account not found', async () => {
      accountRepo.findOne.mockResolvedValue(null);
      await expect(service.findAccount(userId, 'bad-id')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // createAccount
  // ──────────────────────────────────────────────────────────────
  describe('createAccount', () => {
    it('sets isDefault=true for first account', async () => {
      accountRepo.count.mockResolvedValue(0);
      const dto: CreateAccountDto = { name: 'Mi cartera' };
      const created = { ...mockAccount(), id: 'new-id' };
      accountRepo.create.mockReturnValue(created);
      accountRepo.save.mockResolvedValue(created);
      txRepo.create.mockReturnValue({});
      txRepo.save.mockResolvedValue({});

      const result = await service.createAccount(userId, dto);

      expect(accountRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ isDefault: true }),
      );
      expect(result).toEqual(created);
    });

    it('sets isDefault=false when accounts already exist', async () => {
      accountRepo.count.mockResolvedValue(2);
      const dto: CreateAccountDto = { name: 'Segunda cartera' };
      const created = { ...mockAccount(), isDefault: false };
      accountRepo.create.mockReturnValue(created);
      accountRepo.save.mockResolvedValue(created);

      await service.createAccount(userId, dto);

      expect(accountRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ isDefault: false }),
      );
    });

    it('creates initial deposit transaction when initialBalance > 0', async () => {
      accountRepo.count.mockResolvedValue(0);
      const dto: CreateAccountDto = { name: 'Cartera', initialBalance: 500 };
      const saved = { ...mockAccount(), id: 'new-id', balance: 500 };
      accountRepo.create.mockReturnValue(saved);
      accountRepo.save.mockResolvedValue(saved);
      txRepo.create.mockReturnValue({ type: AccountTxType.DEPOSIT });
      txRepo.save.mockResolvedValue({});

      await service.createAccount(userId, dto);

      expect(txRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          type: AccountTxType.DEPOSIT,
          amount: 500,
          description: 'Saldo inicial',
        }),
      );
      expect(txRepo.save).toHaveBeenCalled();
    });

    it('does NOT create transaction when initialBalance is 0', async () => {
      accountRepo.count.mockResolvedValue(0);
      const dto: CreateAccountDto = { name: 'Cartera', initialBalance: 0 };
      const saved = { ...mockAccount(), balance: 0 };
      accountRepo.create.mockReturnValue(saved);
      accountRepo.save.mockResolvedValue(saved);

      await service.createAccount(userId, dto);

      expect(txRepo.create).not.toHaveBeenCalled();
    });
  });

  // ──────────────────────────────────────────────────────────────
  // deposit
  // ──────────────────────────────────────────────────────────────
  describe('deposit', () => {
    it('adds amount to balance and creates DEPOSIT transaction', async () => {
      const acc = mockAccount();
      acc.balance = 100;
      accountRepo.findOne.mockResolvedValue(acc);
      accountRepo.save.mockResolvedValue({ ...acc, balance: 150 });
      txRepo.create.mockReturnValue({ type: AccountTxType.DEPOSIT });
      txRepo.save.mockResolvedValue({});

      const dto: CashOperationDto = { amount: 50 };
      await service.deposit(userId, accountId, dto);

      expect(acc.balance).toBe(150);
      expect(txRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ type: AccountTxType.DEPOSIT, amount: 50 }),
      );
    });

    it('throws NotFoundException when account not found', async () => {
      accountRepo.findOne.mockResolvedValue(null);
      await expect(
        service.deposit(userId, accountId, { amount: 50 }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // withdraw
  // ──────────────────────────────────────────────────────────────
  describe('withdraw', () => {
    it('subtracts amount from balance and creates WITHDRAW transaction', async () => {
      const acc = mockAccount();
      acc.balance = 200;
      accountRepo.findOne.mockResolvedValue(acc);
      accountRepo.save.mockResolvedValue({ ...acc, balance: 150 });
      txRepo.create.mockReturnValue({ type: AccountTxType.WITHDRAW });
      txRepo.save.mockResolvedValue({});

      await service.withdraw(userId, accountId, { amount: 50 });

      expect(acc.balance).toBe(150);
      expect(txRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ type: AccountTxType.WITHDRAW, amount: 50 }),
      );
    });

    it('throws BadRequestException when balance is insufficient', async () => {
      const acc = mockAccount();
      acc.balance = 30;
      accountRepo.findOne.mockResolvedValue(acc);

      await expect(
        service.withdraw(userId, accountId, { amount: 100 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('allows withdrawal when amount equals balance exactly', async () => {
      const acc = mockAccount();
      acc.balance = 100;
      accountRepo.findOne.mockResolvedValue(acc);
      accountRepo.save.mockResolvedValue({ ...acc, balance: 0 });
      txRepo.create.mockReturnValue({});
      txRepo.save.mockResolvedValue({});

      await expect(
        service.withdraw(userId, accountId, { amount: 100 }),
      ).resolves.not.toThrow();
    });

    it('throws BadRequestException when the account is locked', async () => {
      const acc = mockAccount();
      acc.balance = 200;
      acc.isLocked = true;
      accountRepo.findOne.mockResolvedValue(acc);

      await expect(
        service.withdraw(userId, accountId, { amount: 50 }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // getTransactions
  // ──────────────────────────────────────────────────────────────
  describe('getTransactions', () => {
    it('returns transactions ordered by date DESC', async () => {
      const txs = [{ id: 'tx-1' }];
      txRepo.find.mockResolvedValue(txs);

      const result = await service.getTransactions(userId, accountId);

      expect(txRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { accountId, userId },
          take: 100,
        }),
      );
      expect(result).toEqual(txs);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // deleteAccount
  // ──────────────────────────────────────────────────────────────
  describe('deleteAccount', () => {
    it('deletes account with zero balance', async () => {
      const acc = mockAccount();
      acc.balance = 0;
      accountRepo.findOne.mockResolvedValue(acc);
      accountRepo.remove = jest.fn().mockResolvedValue(acc);

      await expect(
        service.deleteAccount(userId, accountId),
      ).resolves.not.toThrow();
      expect(accountRepo.remove).toHaveBeenCalledWith(acc);
    });

    it('throws BadRequestException when account has non-zero balance', async () => {
      const acc = mockAccount();
      acc.balance = 50;
      accountRepo.findOne.mockResolvedValue(acc);

      await expect(service.deleteAccount(userId, accountId)).rejects.toThrow(
        BadRequestException,
      );
    });
  });
});
