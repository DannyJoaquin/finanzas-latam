import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Income } from './income.entity';
import { IncomeRecord } from './income-record.entity';
import { CreateIncomeDto, CreateIncomeRecordDto, UpdateIncomeDto } from './dto/income.dto';

@Injectable()
export class IncomesService {
  constructor(
    @InjectRepository(Income)
    private incomeRepo: Repository<Income>,
    @InjectRepository(IncomeRecord)
    private recordRepo: Repository<IncomeRecord>,
  ) {}

  findAll(userId: string): Promise<Income[]> {
    return this.incomeRepo.find({
      where: { userId, isActive: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(userId: string, id: string): Promise<Income> {
    const income = await this.incomeRepo.findOne({
      where: { id, userId },
      relations: ['records'],
    });
    if (!income) throw new NotFoundException('Income not found');
    return income;
  }

  async create(userId: string, dto: CreateIncomeDto): Promise<Income> {
    const income = this.incomeRepo.create({
      ...dto,
      userId,
      nextExpectedAt: dto.nextExpectedAt ? new Date(dto.nextExpectedAt) : undefined,
    });
    return this.incomeRepo.save(income);
  }

  async update(userId: string, id: string, dto: UpdateIncomeDto): Promise<Income> {
    const income = await this.findOne(userId, id);
    Object.assign(income, dto);
    return this.incomeRepo.save(income);
  }

  async remove(userId: string, id: string): Promise<void> {
    const income = await this.findOne(userId, id);
    income.isActive = false;
    await this.incomeRepo.save(income);
  }

  async addRecord(
    userId: string,
    incomeId: string,
    dto: CreateIncomeRecordDto,
  ): Promise<IncomeRecord> {
    await this.findOne(userId, incomeId); // validates ownership
    const record = this.recordRepo.create({
      ...dto,
      userId,
      incomeId,
      receivedAt: new Date(dto.receivedAt),
    });
    return this.recordRepo.save(record);
  }

  getRecords(userId: string, incomeId: string): Promise<IncomeRecord[]> {
    return this.recordRepo.find({
      where: { incomeId, userId },
      order: { receivedAt: 'DESC' },
    });
  }

  /** Returns projected incomes for the next 90 days */
  async getProjection(userId: string): Promise<{ date: string; amount: number; sourceName: string }[]> {
    const incomes = await this.findAll(userId);
    const projections: { date: string; amount: number; sourceName: string }[] = [];
    const today = new Date();

    for (const income of incomes) {
      if (!income.nextExpectedAt) continue;
      const next = new Date(income.nextExpectedAt);
      const ninetydDays = new Date(today);
      ninetydDays.setDate(today.getDate() + 90);

      let current = new Date(next);
      while (current <= ninetydDays) {
        projections.push({
          date: current.toISOString().split('T')[0],
          amount: Number(income.amount),
          sourceName: income.sourceName,
        });
        // Advance by cycle
        const copy = new Date(current);
        if (income.cycle === 'monthly') copy.setMonth(copy.getMonth() + 1);
        else if (income.cycle === 'biweekly') copy.setDate(copy.getDate() + 15);
        else if (income.cycle === 'weekly') copy.setDate(copy.getDate() + 7);
        else break; // one_time
        current = copy;
      }
    }

    return projections.sort((a, b) => a.date.localeCompare(b.date));
  }
}
