import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Budget } from './budget.entity';
import { CreateBudgetDto, UpdateBudgetDto } from './dto/budget.dto';
import { getCurrentPeriod } from '../../common/utils/date-cycle.util';
import { PayCycle } from '../users/user.entity';

@Injectable()
export class BudgetsService {
  constructor(
    @InjectRepository(Budget)
    private budgetRepo: Repository<Budget>,
  ) {}

  async findCurrentPeriod(userId: string): Promise<(Budget & { spent: number; percentage: number })[]> {
    const today = new Date();
    const budgets = await this.budgetRepo
      .createQueryBuilder('b')
      .leftJoinAndSelect('b.category', 'cat')
      .where('b.userId = :userId', { userId })
      .andWhere('b.isActive = true')
      .andWhere('b.periodStart <= :today', { today })
      .andWhere('b.periodEnd >= :today', { today })
      .getMany();

    const enriched = await Promise.all(
      budgets.map(async (budget) => {
        const spentResult = await this.budgetRepo.manager
          .createQueryBuilder()
          .select('COALESCE(SUM(e.amount), 0)', 'total')
          .from('expenses', 'e')
          .where('e.user_id = :userId', { userId })
          .andWhere('e.date BETWEEN :start AND :end', {
            start: budget.periodStart,
            end: budget.periodEnd,
          })
          .andWhere(budget.categoryId ? 'e.category_id = :catId' : '1=1', {
            catId: budget.categoryId,
          })
          .getRawOne<{ total: string }>();

        const spent = parseFloat(spentResult?.total ?? '0');
        const percentage = budget.amount > 0 ? (spent / Number(budget.amount)) * 100 : 0;
        return { ...budget, spent, percentage };
      }),
    );

    return enriched;
  }

  async findOne(userId: string, id: string): Promise<Budget & { spent: number; percentage: number }> {
    const budget = await this.budgetRepo.findOne({
      where: { id, userId },
      relations: ['category'],
    });
    if (!budget) throw new NotFoundException('Budget not found');
    const spentResult = await this.budgetRepo.manager
      .createQueryBuilder()
      .select('COALESCE(SUM(e.amount), 0)', 'total')
      .from('expenses', 'e')
      .where('e.user_id = :userId', { userId })
      .andWhere('e.date BETWEEN :start AND :end', {
        start: budget.periodStart,
        end: budget.periodEnd,
      })
      .andWhere(budget.categoryId ? 'e.category_id = :catId' : '1=1', {
        catId: budget.categoryId,
      })
      .getRawOne<{ total: string }>();
    const spent = parseFloat(spentResult?.total ?? '0');
    const percentage = Number(budget.amount) > 0 ? (spent / Number(budget.amount)) * 100 : 0;
    return { ...budget, spent, percentage };
  }

  async create(userId: string, dto: CreateBudgetDto): Promise<Budget> {
    const newStart = new Date(dto.periodStart);
    const newEnd = new Date(dto.periodEnd);

    const existing = await this.budgetRepo
      .createQueryBuilder('b')
      .where('b.userId = :userId', { userId })
      .andWhere('b.categoryId = :categoryId', { categoryId: dto.categoryId ?? null })
      .andWhere('b.periodType = :periodType', { periodType: dto.periodType })
      .andWhere('b.isActive = true')
      .andWhere('b.periodStart <= :newEnd', { newEnd })
      .andWhere('b.periodEnd >= :newStart', { newStart })
      .getOne();

    if (existing) throw new BadRequestException(`Ya tienes un presupuesto activo "${existing.name}" para esta categoría en ese período. Edítalo desde la lista.`);
    const budget = this.budgetRepo.create({
      ...dto,
      userId,
      periodStart: newStart,
      periodEnd: newEnd,
    });
    return this.budgetRepo.save(budget);
  }

  async update(userId: string, id: string, dto: UpdateBudgetDto): Promise<Budget> {
    const budget = await this.findOne(userId, id);
    const updateData = {
      ...dto,
      ...(dto.periodStart ? { periodStart: new Date(dto.periodStart) } : {}),
      ...(dto.periodEnd ? { periodEnd: new Date(dto.periodEnd) } : {}),
    };
    Object.assign(budget, updateData);
    return this.budgetRepo.save(budget);
  }

  async remove(userId: string, id: string): Promise<void> {
    const budget = await this.findOne(userId, id);
    await this.budgetRepo.remove(budget);
  }

  /** Marks alert flags — called by cron job */
  async checkAndMarkAlerts(budget: Budget, spent: number): Promise<void> {
    const pct = Number(budget.amount) > 0 ? (spent / Number(budget.amount)) * 100 : 0;
    let changed = false;
    if (pct >= 50 && !budget.alert50Sent) { budget.alert50Sent = true; changed = true; }
    if (pct >= 80 && !budget.alert80Sent) { budget.alert80Sent = true; changed = true; }
    if (pct >= 100 && !budget.alert100Sent) { budget.alert100Sent = true; changed = true; }
    if (changed) await this.budgetRepo.save(budget);
  }
}
