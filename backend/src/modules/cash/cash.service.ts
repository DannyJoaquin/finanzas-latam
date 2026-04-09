import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  IsDateString, IsNumber, IsOptional, IsPositive, IsString, Length, Min,
} from 'class-validator';
import { CashAccount } from './cash-account.entity';
import { CashTransaction, CashTxType } from './cash-transaction.entity';

export class CreateCashAccountDto {
  @IsString()
  @Length(1, 100)
  name: string;

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

@Injectable()
export class CashService {
  constructor(
    @InjectRepository(CashAccount)
    private accountRepo: Repository<CashAccount>,
    @InjectRepository(CashTransaction)
    private txRepo: Repository<CashTransaction>,
  ) {}

  findAccounts(userId: string): Promise<CashAccount[]> {
    return this.accountRepo.find({
      where: { userId },
      order: { isDefault: 'DESC', sortOrder: 'ASC' },
    });
  }

  async findAccount(userId: string, id: string): Promise<CashAccount> {
    const acc = await this.accountRepo.findOne({ where: { id, userId } });
    if (!acc) throw new NotFoundException('Cash account not found');
    return acc;
  }

  async createAccount(userId: string, dto: CreateCashAccountDto): Promise<CashAccount> {
    const existingCount = await this.accountRepo.count({ where: { userId } });
    const account = this.accountRepo.create({
      ...dto,
      userId,
      balance: dto.initialBalance ?? 0,
      isDefault: existingCount === 0,
    });
    const saved = await this.accountRepo.save(account);

    if (dto.initialBalance && dto.initialBalance > 0) {
      const tx = this.txRepo.create({
        cashAccountId: saved.id,
        userId,
        type: CashTxType.DEPOSIT,
        amount: dto.initialBalance,
        description: 'Saldo inicial',
        date: new Date(),
      });
      await this.txRepo.save(tx);
    }
    return saved;
  }

  async deposit(userId: string, accountId: string, dto: CashOperationDto): Promise<CashAccount> {
    const account = await this.findAccount(userId, accountId);
    account.balance = Number(account.balance) + Number(dto.amount);
    await this.accountRepo.save(account);

    const tx = this.txRepo.create({
      cashAccountId: accountId,
      userId,
      type: CashTxType.DEPOSIT,
      amount: dto.amount,
      description: dto.description ?? 'Depósito',
      date: dto.date ? new Date(dto.date) : new Date(),
    });
    await this.txRepo.save(tx);
    return account;
  }

  async withdraw(userId: string, accountId: string, dto: CashOperationDto): Promise<CashAccount> {
    const account = await this.findAccount(userId, accountId);
    if (Number(account.balance) < Number(dto.amount)) {
      throw new BadRequestException('Insufficient cash balance');
    }
    account.balance = Number(account.balance) - Number(dto.amount);
    await this.accountRepo.save(account);

    const tx = this.txRepo.create({
      cashAccountId: accountId,
      userId,
      type: CashTxType.WITHDRAW,
      amount: dto.amount,
      description: dto.description ?? 'Retiro',
      date: dto.date ? new Date(dto.date) : new Date(),
    });
    await this.txRepo.save(tx);
    return account;
  }

  getTransactions(userId: string, accountId: string): Promise<CashTransaction[]> {
    return this.txRepo.find({
      where: { cashAccountId: accountId, userId },
      order: { date: 'DESC', createdAt: 'DESC' },
      take: 100,
    });
  }

  async deleteAccount(userId: string, id: string): Promise<void> {
    const account = await this.findAccount(userId, id);
    if (Number(account.balance) !== 0) {
      throw new BadRequestException('Cannot delete account with non-zero balance');
    }
    await this.accountRepo.remove(account);
  }
}
