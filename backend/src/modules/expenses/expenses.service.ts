import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, ILike, MoreThan, Repository } from 'typeorm';
import { Expense, PaymentMethod } from './expense.entity';
import { CreateExpenseDto, FilterExpensesDto, UpdateExpenseDto } from './dto/expense.dto';
import { parsePagination, buildMeta } from '../../common/utils/pagination.util';

@Injectable()
export class ExpensesService {
  constructor(
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
  ) {}

  async findAll(userId: string, filters: FilterExpensesDto) {
    const { skip, take, page, limit } = parsePagination(filters);

    const qb = this.expenseRepo
      .createQueryBuilder('e')
      .leftJoinAndSelect('e.category', 'cat')
      .where('e.userId = :userId', { userId })
      .orderBy('e.date', 'DESC')
      .addOrderBy('e.createdAt', 'DESC')
      .skip(skip)
      .take(take);

    if (filters.startDate) qb.andWhere('e.date >= :start', { start: filters.startDate });
    if (filters.endDate) qb.andWhere('e.date <= :end', { end: filters.endDate });
    if (filters.categoryId) qb.andWhere('e.categoryId = :catId', { catId: filters.categoryId });
    if (filters.paymentMethod) qb.andWhere('e.paymentMethod = :method', { method: filters.paymentMethod });
    if (filters.search) {
      qb.andWhere('e.description ILIKE :search', { search: `%${filters.search}%` });
    }

    const [items, total] = await qb.getManyAndCount();
    return { items, meta: buildMeta(total, page, limit) };
  }

  async findOne(userId: string, id: string): Promise<Expense> {
    const expense = await this.expenseRepo.findOne({
      where: { id, userId },
      relations: ['category', 'cashAccount'],
    });
    if (!expense) throw new NotFoundException('Expense not found');
    return expense;
  }

  async create(userId: string, dto: CreateExpenseDto): Promise<Expense> {
    const expenseDate = new Date(dto.date);
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    if (expenseDate > tomorrow) {
      throw new BadRequestException('Expense date cannot be in the future');
    }
    // Duplicate detection: same user + amount + category + date + description within 5 seconds
    const fiveSecondsAgo = new Date(Date.now() - 5000);
    const duplicate = await this.expenseRepo.findOne({
      where: {
        userId,
        amount: dto.amount as any,
        categoryId: dto.categoryId ?? (null as any),
        description: dto.description ?? '',
        createdAt: MoreThan(fiveSecondsAgo),
      },
    });
    if (duplicate) throw new ConflictException('Duplicate expense detected: identical expense submitted within 5 seconds');
    const expense = this.expenseRepo.create({ ...dto, userId, date: expenseDate });
    try {
      return await this.expenseRepo.save(expense);
    } catch (err: any) {
      if (err?.code === '23503') {
        throw new BadRequestException('Invalid categoryId: category does not exist');
      }
      throw err;
    }
  }

  async update(userId: string, id: string, dto: UpdateExpenseDto): Promise<Expense> {
    const expense = await this.findOne(userId, id);
    const updateData = { ...dto, ...(dto.date ? { date: new Date(dto.date) } : {}) };
    Object.assign(expense, updateData);
    return this.expenseRepo.save(expense);
  }

  async remove(userId: string, id: string): Promise<void> {
    const expense = await this.findOne(userId, id);
    await this.expenseRepo.remove(expense);
  }

  async getSummary(userId: string, startDate?: string, endDate?: string) {
    const now = new Date();
    const effectiveStart =
      startDate ||
      `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
    const effectiveEnd =
      endDate || now.toISOString().split('T')[0];

    const result = await this.expenseRepo
      .createQueryBuilder('e')
      .select('cat.id', 'categoryId')
      .addSelect('cat.name', 'categoryName')
      .addSelect('cat.icon', 'categoryIcon')
      .addSelect('cat.color', 'categoryColor')
      .addSelect('SUM(e.amount)', 'total')
      .addSelect('COUNT(e.id)', 'count')
      .leftJoin('e.category', 'cat')
      .where('e.userId = :userId', { userId })
      .andWhere('e.date BETWEEN :start AND :end', { start: effectiveStart, end: effectiveEnd })
      .groupBy('cat.id')
      .addGroupBy('cat.name')
      .addGroupBy('cat.icon')
      .addGroupBy('cat.color')
      .orderBy('total', 'DESC')
      .getRawMany();

    const grandTotal = result.reduce((sum, r) => sum + parseFloat(r.total ?? '0'), 0);
    return { categories: result, grandTotal };
  }

  async getSummaryByMethod(userId: string, startDate?: string, endDate?: string) {
    const now = new Date();
    const effectiveStart =
      startDate ||
      `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
    const effectiveEnd = endDate || now.toISOString().split('T')[0];

    const result = await this.expenseRepo
      .createQueryBuilder('e')
      .select('e.paymentMethod', 'method')
      .addSelect('SUM(e.amount)', 'total')
      .where('e.userId = :userId', { userId })
      .andWhere('e.date BETWEEN :start AND :end', { start: effectiveStart, end: effectiveEnd })
      .groupBy('e.paymentMethod')
      .orderBy('total', 'DESC')
      .getRawMany<{ method: string; total: string }>();

    const grandTotal = result.reduce((sum, r) => sum + parseFloat(r.total ?? '0'), 0);
    const breakdown = result.map((r) => {
      const amount = parseFloat(r.total ?? '0');
      return {
        method: r.method as PaymentMethod,
        amount,
        percentage: grandTotal > 0 ? Math.round((amount / grandTotal) * 1000) / 10 : 0,
      };
    });

    return { breakdown, total: grandTotal };
  }
}
