import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Length,
  Min,
} from 'class-validator';
import { Account, AccountType } from './account.entity';
import {
  AccountTransaction,
  AccountTxType,
} from './account-transaction.entity';

export class CreateAccountDto {
  @IsString()
  @Length(1, 100)
  name: string;

  @IsOptional()
  @IsEnum(AccountType)
  type?: AccountType;

  @IsOptional()
  @IsString()
  @Length(1, 10)
  currency?: string;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  icon?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  initialBalance?: number;

  @IsOptional()
  @IsString()
  institution?: string;

  @IsOptional()
  @IsBoolean()
  isAvailableForExpenses?: boolean;

  @IsOptional()
  @IsBoolean()
  isLocked?: boolean;

  @IsOptional()
  @IsDateString()
  lockedUntil?: string;

  @IsOptional()
  @IsNumber()
  interestRateAnnual?: number;

  @IsOptional()
  @IsDateString()
  openedAt?: string;
}

export class UpdateAccountDto {
  @IsOptional()
  @IsString()
  @Length(1, 100)
  name?: string;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  icon?: string;

  @IsOptional()
  @IsString()
  institution?: string;

  @IsOptional()
  @IsBoolean()
  isAvailableForExpenses?: boolean;

  @IsOptional()
  @IsBoolean()
  isLocked?: boolean;

  @IsOptional()
  @IsDateString()
  lockedUntil?: string;

  @IsOptional()
  @IsNumber()
  interestRateAnnual?: number;

  @IsOptional()
  @IsDateString()
  openedAt?: string;
}

export class CashOperationDto {
  @IsNumber()
  @IsPositive()
  amount: number;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsDateString()
  date?: string;
}

export class UpdateCashTransactionDto {
  @IsOptional()
  @IsNumber()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsDateString()
  date?: string;
}

@Injectable()
export class AccountsService {
  constructor(
    @InjectRepository(Account)
    private accountRepo: Repository<Account>,
    @InjectRepository(AccountTransaction)
    private txRepo: Repository<AccountTransaction>,
  ) {}

  findAccounts(userId: string): Promise<Account[]> {
    return this.accountRepo.find({
      where: { userId },
      order: { isDefault: 'DESC', sortOrder: 'ASC' },
    });
  }

  async findAccount(userId: string, id: string): Promise<Account> {
    const acc = await this.accountRepo.findOne({ where: { id, userId } });
    if (!acc) throw new NotFoundException('Account not found');
    return acc;
  }

  async createAccount(userId: string, dto: CreateAccountDto): Promise<Account> {
    const existingCount = await this.accountRepo.count({ where: { userId } });
    const account = this.accountRepo.create({
      ...dto,
      userId,
      balance: dto.initialBalance ?? 0,
      isDefault: existingCount === 0,
      lockedUntil: dto.lockedUntil ? new Date(dto.lockedUntil) : null,
      openedAt: dto.openedAt ? new Date(dto.openedAt) : null,
    });
    const saved = await this.accountRepo.save(account);

    if (dto.initialBalance && dto.initialBalance > 0) {
      const tx = this.txRepo.create({
        accountId: saved.id,
        userId,
        type: AccountTxType.DEPOSIT,
        amount: dto.initialBalance,
        description: 'Saldo inicial',
        date: new Date(),
      });
      await this.txRepo.save(tx);
    }
    return saved;
  }

  async updateAccount(
    userId: string,
    id: string,
    dto: UpdateAccountDto,
  ): Promise<Account> {
    const account = await this.findAccount(userId, id);
    Object.assign(account, {
      ...dto,
      ...(dto.lockedUntil !== undefined
        ? { lockedUntil: dto.lockedUntil ? new Date(dto.lockedUntil) : null }
        : {}),
      ...(dto.openedAt !== undefined
        ? { openedAt: dto.openedAt ? new Date(dto.openedAt) : null }
        : {}),
    });
    return this.accountRepo.save(account);
  }

  async deposit(
    userId: string,
    accountId: string,
    dto: CashOperationDto,
  ): Promise<Account> {
    const account = await this.findAccount(userId, accountId);
    account.balance = Number(account.balance) + Number(dto.amount);
    await this.accountRepo.save(account);

    const tx = this.txRepo.create({
      accountId,
      userId,
      type: AccountTxType.DEPOSIT,
      amount: dto.amount,
      description: dto.description ?? 'Depósito',
      date: dto.date ? new Date(dto.date) : new Date(),
    });
    await this.txRepo.save(tx);
    return account;
  }

  async withdraw(
    userId: string,
    accountId: string,
    dto: CashOperationDto,
  ): Promise<Account> {
    const account = await this.findAccount(userId, accountId);
    if (account.isLocked) {
      throw new BadRequestException('Cannot withdraw from a locked account');
    }
    if (Number(account.balance) < Number(dto.amount)) {
      throw new BadRequestException('Insufficient account balance');
    }
    account.balance = Number(account.balance) - Number(dto.amount);
    await this.accountRepo.save(account);

    const tx = this.txRepo.create({
      accountId,
      userId,
      type: AccountTxType.WITHDRAW,
      amount: dto.amount,
      description: dto.description ?? 'Retiro',
      date: dto.date ? new Date(dto.date) : new Date(),
    });
    await this.txRepo.save(tx);
    return account;
  }

  getTransactions(
    userId: string,
    accountId: string,
  ): Promise<AccountTransaction[]> {
    return this.txRepo.find({
      where: { accountId, userId },
      order: { date: 'DESC', createdAt: 'DESC' },
      take: 100,
    });
  }

  async updateTransaction(
    userId: string,
    accountId: string,
    transactionId: string,
    dto: UpdateCashTransactionDto,
  ): Promise<AccountTransaction> {
    const account = await this.findAccount(userId, accountId);
    const transaction = await this.txRepo.findOne({
      where: { id: transactionId, accountId, userId },
    });
    if (!transaction)
      throw new NotFoundException('Account transaction not found');
    if (
      transaction.type !== AccountTxType.DEPOSIT &&
      transaction.type !== AccountTxType.WITHDRAW
    ) {
      throw new BadRequestException(
        'Only deposits and withdrawals can be edited',
      );
    }

    const oldEffect =
      transaction.type === AccountTxType.DEPOSIT
        ? Number(transaction.amount)
        : -Number(transaction.amount);
    const newAmount = dto.amount ?? Number(transaction.amount);
    const newEffect =
      transaction.type === AccountTxType.DEPOSIT ? newAmount : -newAmount;
    const nextBalance = Number(account.balance) - oldEffect + newEffect;
    if (nextBalance < 0)
      throw new BadRequestException('Insufficient account balance');

    account.balance = nextBalance;
    await this.accountRepo.save(account);
    Object.assign(transaction, {
      amount: newAmount,
      description: dto.description ?? transaction.description,
      ...(dto.date ? { date: new Date(dto.date) } : {}),
    });
    return this.txRepo.save(transaction);
  }

  async deleteTransaction(
    userId: string,
    accountId: string,
    transactionId: string,
  ): Promise<void> {
    const account = await this.findAccount(userId, accountId);
    const transaction = await this.txRepo.findOne({
      where: { id: transactionId, accountId, userId },
    });
    if (!transaction)
      throw new NotFoundException('Account transaction not found');
    if (
      transaction.type !== AccountTxType.DEPOSIT &&
      transaction.type !== AccountTxType.WITHDRAW
    ) {
      throw new BadRequestException(
        'Only deposits and withdrawals can be deleted',
      );
    }

    const effect =
      transaction.type === AccountTxType.DEPOSIT
        ? Number(transaction.amount)
        : -Number(transaction.amount);
    const nextBalance = Number(account.balance) - effect;
    if (nextBalance < 0) {
      throw new BadRequestException(
        'Cannot delete deposit: balance would become negative',
      );
    }

    account.balance = nextBalance;
    await this.accountRepo.save(account);
    await this.txRepo.remove(transaction);
  }

  async deleteAccount(userId: string, id: string): Promise<void> {
    const account = await this.findAccount(userId, id);
    if (Number(account.balance) !== 0) {
      throw new BadRequestException(
        'Cannot delete account with non-zero balance',
      );
    }
    await this.accountRepo.remove(account);
  }
}
