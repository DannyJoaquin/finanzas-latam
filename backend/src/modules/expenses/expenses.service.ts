import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, ILike, MoreThan, Repository } from 'typeorm';
import { Expense, PaymentMethod } from './expense.entity';
import { CreateExpenseDto, FilterExpensesDto, UpdateExpenseDto } from './dto/expense.dto';
import { parsePagination, buildMeta } from '../../common/utils/pagination.util';
import { CashAccount } from '../cash/cash-account.entity';
import { CashTransaction, CashTxType } from '../cash/cash-transaction.entity';
import { ExpenseCategorizationService } from '../categorization/expense-categorization.service';
import { CategorizationLearningService } from '../categorization/categorization-learning.service';

@Injectable()
export class ExpensesService {
  constructor(
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    @InjectRepository(CashAccount)
    private cashAccountRepo: Repository<CashAccount>,
    @InjectRepository(CashTransaction)
    private cashTxRepo: Repository<CashTransaction>,
    private categorizationService: ExpenseCategorizationService,
    private learningService: CategorizationLearningService,
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
    if (filters.creditCardId) qb.andWhere('e.creditCardId = :creditCardId', { creditCardId: filters.creditCardId });
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

    // Auto-categorize if no category provided
    let resolvedCategoryId = dto.categoryId;
    let wasAutoAssigned = false;
    let suggestionResult = null;
    if (!resolvedCategoryId && dto.description?.trim()) {
      try {
        suggestionResult = await this.categorizationService.suggest(userId, dto.description);
        if (this.categorizationService.shouldAutoAssign(suggestionResult.confidence)) {
          resolvedCategoryId = suggestionResult.suggestedCategoryId ?? undefined;
          wasAutoAssigned = true;
        }
      } catch {
        // Auto-categorization is best-effort; don't fail the expense creation
      }
    }

    const expense = this.expenseRepo.create({
      ...dto,
      categoryId: resolvedCategoryId,
      userId,
      date: expenseDate,
    });
    let saved: Expense;
    try {
      saved = await this.expenseRepo.save(expense);
    } catch (err: any) {
      if (err?.code === '23503') {
        throw new BadRequestException('Invalid categoryId: category does not exist');
      }
      throw err;
    }

    // Write audit log (best-effort)
    if (suggestionResult && suggestionResult.confidence !== 'none') {
      try {
        await this.categorizationService.createAuditLog(
          userId,
          dto.description ?? null,
          suggestionResult,
          { expenseId: saved.id, wasAutoAssigned },
        );
      } catch { /* best-effort */ }
    }

    // Auto-deduct from cash account when payment method is cash
    if (saved.paymentMethod === PaymentMethod.CASH) {
      try {
        const accountId = dto.cashAccountId ?? undefined;
        const account = accountId
          ? await this.cashAccountRepo.findOne({ where: { id: accountId, userId } })
          : await this.cashAccountRepo.findOne({
              where: { userId, isDefault: true },
            }) ??
            (await this.cashAccountRepo.find({ where: { userId }, order: { createdAt: 'ASC' }, take: 1 }))[0];

        if (account) {
          account.balance = Number(account.balance) - Number(saved.amount);
          await this.cashAccountRepo.save(account);
          const tx = this.cashTxRepo.create({
            cashAccountId: account.id,
            userId,
            type: CashTxType.SPEND,
            amount: saved.amount,
            description: saved.description || 'Gasto en efectivo',
            date: expenseDate,
            expenseId: saved.id,
          });
          await this.cashTxRepo.save(tx);
        }
      } catch {
        // Cash deduction is best-effort; don't fail the expense creation
      }
    }

    return saved;
  }

  async update(userId: string, id: string, dto: UpdateExpenseDto): Promise<Expense> {
    const expense = await this.findOne(userId, id);
    const categoryChanged =
      dto.categoryId !== undefined && dto.categoryId !== expense.categoryId;

    const updateData = { ...dto, ...(dto.date ? { date: new Date(dto.date) } : {}) };
    Object.assign(expense, updateData);
    const saved = await this.expenseRepo.save(expense);

    // Trigger learning when user manually changes the category
    if (categoryChanged && dto.categoryId && expense.description) {
      try {
        await this.learningService.recordFeedback(
          userId,
          expense.description,
          dto.categoryId,
          { remember: false },
        );
        await this.categorizationService.markCorrected(userId, id, dto.categoryId);
      } catch { /* best-effort */ }
    }

    return saved;
  }

  async remove(userId: string, id: string): Promise<void> {
    const expense = await this.findOne(userId, id);

    // Reverse cash deduction if this expense had one
    if (expense.paymentMethod === PaymentMethod.CASH) {
      try {
        const tx = await this.cashTxRepo.findOne({
          where: { expenseId: expense.id, userId },
        });
        if (tx) {
          const account = await this.cashAccountRepo.findOne({
            where: { id: tx.cashAccountId, userId },
          });
          if (account) {
            account.balance = Number(account.balance) + Number(expense.amount);
            await this.cashAccountRepo.save(account);
          }
          await this.cashTxRepo.remove(tx);
        }
      } catch {
        // Reversal is best-effort
      }
    }

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
