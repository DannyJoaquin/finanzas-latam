import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThanOrEqual, Repository } from 'typeorm';
import { Category } from '../categories/category.entity';
import { CashAccount } from '../cash/cash-account.entity';
import { CreditCard } from '../credit-cards/credit-card.entity';
import { Expense, ExpenseSource, PaymentMethod } from '../expenses/expense.entity';
import { ExpensesService } from '../expenses/expenses.service';
import {
  CreateRecurringExpenseDto,
  UpdateRecurringExpenseDto,
} from './dto/recurring-expense.dto';
import { RecurringExpense, RecurringFrequency } from './recurring-expense.entity';
import {
  dateOnly,
  firstOccurrenceOnOrAfter,
  firstScheduledDate,
  formatDateOnly,
  nextOccurrenceAfter,
} from './recurring-expenses.schedule';

const MAX_CATCH_UP_OCCURRENCES = 3660;

@Injectable()
export class RecurringExpensesService {
  constructor(
    @InjectRepository(RecurringExpense)
    private recurringRepo: Repository<RecurringExpense>,
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    @InjectRepository(Category)
    private categoryRepo: Repository<Category>,
    @InjectRepository(CashAccount)
    private cashAccountRepo: Repository<CashAccount>,
    @InjectRepository(CreditCard)
    private creditCardRepo: Repository<CreditCard>,
    private expensesService: ExpensesService,
  ) {}

  async findAll(userId: string): Promise<RecurringExpense[]> {
    await this.processDueForUser(userId);
    return this.recurringRepo.find({
      where: { userId },
      relations: ['category', 'cashAccount', 'creditCard'],
      order: { isActive: 'DESC', nextRunDate: 'ASC', name: 'ASC' },
    });
  }

  async findOne(userId: string, id: string): Promise<RecurringExpense> {
    const recurring = await this.recurringRepo.findOne({
      where: { id, userId },
      relations: ['category', 'cashAccount', 'creditCard'],
    });
    if (!recurring) throw new NotFoundException('Recurring expense not found');
    return recurring;
  }

  async upcoming(userId: string, limit = 10): Promise<RecurringExpense[]> {
    await this.processDueForUser(userId);
    return this.recurringRepo.find({
      where: { userId, isActive: true },
      relations: ['category', 'cashAccount', 'creditCard'],
      order: { nextRunDate: 'ASC' },
      take: Math.min(Math.max(limit, 1), 50),
    });
  }

  async create(userId: string, dto: CreateRecurringExpenseDto): Promise<RecurringExpense> {
    const paymentMethod = dto.paymentMethod ?? PaymentMethod.CASH;
    const startDate = firstScheduledDate(
      dto.startDate,
      dto.frequency,
      dto.executionDay,
    );

    await this.validateCategory(userId, dto.categoryId);
    await this.validatePaymentTarget(userId, paymentMethod, dto.cashAccountId, dto.creditCardId);
    this.validateExecutionDay(dto.frequency, dto.executionDay);

    const recurring = this.recurringRepo.create({
      userId,
      name: dto.name.trim(),
      amount: dto.amount,
      currency: dto.currency ?? 'HNL',
      categoryId: dto.categoryId,
      paymentMethod,
      cashAccountId: dto.cashAccountId ?? null,
      creditCardId: dto.creditCardId ?? null,
      notes: dto.notes?.trim() || null,
      frequency: dto.frequency,
      executionDay: dto.executionDay,
      startDate,
      nextRunDate: startDate,
      lastGeneratedDate: null,
      isActive: true,
      pausedAt: null,
      lastGenerationAttemptAt: null,
      lastGenerationError: null,
    });

    try {
      return await this.recurringRepo.save(recurring);
    } catch (error: any) {
      if (error?.code === '23503') {
        throw new BadRequestException('Invalid category or payment account');
      }
      throw error;
    }
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateRecurringExpenseDto,
  ): Promise<RecurringExpense> {
    const recurring = await this.findOne(userId, id);
    const wasActive = recurring.isActive;
    const scheduleChanged =
      dto.frequency !== undefined ||
      dto.executionDay !== undefined ||
      dto.startDate !== undefined;

    if (dto.name !== undefined) recurring.name = dto.name.trim();
    if (dto.amount !== undefined) recurring.amount = dto.amount;
    if (dto.currency !== undefined) recurring.currency = dto.currency;
    if (dto.categoryId !== undefined) {
      await this.validateCategory(userId, dto.categoryId);
      recurring.categoryId = dto.categoryId;
    }
    if (dto.paymentMethod !== undefined) recurring.paymentMethod = dto.paymentMethod;
    if (dto.cashAccountId !== undefined) recurring.cashAccountId = dto.cashAccountId ?? null;
    if (dto.creditCardId !== undefined) recurring.creditCardId = dto.creditCardId ?? null;
    if (dto.notes !== undefined) recurring.notes = dto.notes?.trim() || null;
    if (dto.frequency !== undefined) recurring.frequency = dto.frequency;
    if (dto.executionDay !== undefined) recurring.executionDay = dto.executionDay;
    if (dto.startDate !== undefined) recurring.startDate = dateOnly(dto.startDate);
    if (dto.isActive !== undefined) recurring.isActive = dto.isActive;

    if (recurring.paymentMethod !== PaymentMethod.CASH) recurring.cashAccountId = null;
    if (recurring.paymentMethod !== PaymentMethod.CARD_CREDIT) recurring.creditCardId = null;
    await this.validatePaymentTarget(
      userId,
      recurring.paymentMethod,
      recurring.cashAccountId,
      recurring.creditCardId,
    );
    this.validateExecutionDay(recurring.frequency, recurring.executionDay);

    if (!wasActive && recurring.isActive) {
      recurring.nextRunDate = firstOccurrenceOnOrAfter(
        recurring.startDate,
        this.today(),
        recurring.frequency,
        recurring.executionDay,
      );
      recurring.pausedAt = null;
    } else if (wasActive && !recurring.isActive) {
      recurring.pausedAt = new Date();
    } else if (scheduleChanged && recurring.isActive) {
      const anchor = dto.startDate ? dateOnly(dto.startDate) : this.today();
      recurring.startDate = anchor;
      recurring.nextRunDate = firstOccurrenceOnOrAfter(
        anchor,
        this.today(),
        recurring.frequency,
        recurring.executionDay,
      );
    }

    return this.recurringRepo.save(recurring);
  }

  async remove(userId: string, id: string): Promise<void> {
    const recurring = await this.findOne(userId, id);
    await this.recurringRepo.remove(recurring);
  }

  async processAllDue(): Promise<number> {
    const due = await this.recurringRepo.find({
      where: {
        isActive: true,
        nextRunDate: LessThanOrEqual(this.today()),
      },
      order: { nextRunDate: 'ASC' },
    });

    let processed = 0;
    for (const recurring of due) {
      processed += await this.processOne(recurring);
    }
    return processed;
  }

  async processDueForUser(userId: string): Promise<number> {
    const due = await this.recurringRepo.find({
      where: {
        userId,
        isActive: true,
        nextRunDate: LessThanOrEqual(this.today()),
      },
      order: { nextRunDate: 'ASC' },
    });

    let processed = 0;
    for (const recurring of due) {
      processed += await this.processOne(recurring);
    }
    return processed;
  }

  private async processOne(recurring: RecurringExpense): Promise<number> {
    const today = this.today();
    let processed = 0;
    let attempts = 0;

    while (recurring.isActive && dateOnly(recurring.nextRunDate) <= today) {
      if (attempts++ >= MAX_CATCH_UP_OCCURRENCES) break;

      const scheduledDate = dateOnly(recurring.nextRunDate);
      recurring.lastGenerationAttemptAt = new Date();

      try {
        const existing = await this.expenseRepo.findOne({
          where: {
            recurringExpenseId: recurring.id,
            recurringScheduledDate: scheduledDate,
          },
        });

        if (!existing) {
          await this.expensesService.create(
            recurring.userId,
            {
              amount: Number(recurring.amount),
              date: formatDateOnly(scheduledDate),
              categoryId: recurring.categoryId,
              description: recurring.name,
              paymentMethod: recurring.paymentMethod,
              cashAccountId: recurring.cashAccountId ?? undefined,
              creditCardId: recurring.creditCardId ?? undefined,
              currency: recurring.currency,
              source: ExpenseSource.AUTO,
            },
            {
              recurringExpenseId: recurring.id,
              recurringScheduledDate: formatDateOnly(scheduledDate),
            },
          );
          processed++;
        }

        recurring.lastGeneratedDate = scheduledDate;
        recurring.nextRunDate = nextOccurrenceAfter(
          scheduledDate,
          recurring.frequency,
          recurring.executionDay,
        );
        recurring.lastGenerationError = null;
        await this.recurringRepo.save(recurring);
      } catch (error: any) {
        if (error?.code === '23505') {
          recurring.lastGeneratedDate = scheduledDate;
          recurring.nextRunDate = nextOccurrenceAfter(
            scheduledDate,
            recurring.frequency,
            recurring.executionDay,
          );
          recurring.lastGenerationError = null;
          await this.recurringRepo.save(recurring);
          continue;
        }

        recurring.lastGenerationError = this.errorMessage(error);
        await this.recurringRepo.save(recurring).catch(() => undefined);
        break;
      }
    }

    return processed;
  }

  private async validateCategory(userId: string, categoryId: string): Promise<void> {
    const category = await this.categoryRepo.findOne({ where: { id: categoryId } });
    if (!category || (!category.isSystem && category.userId !== userId)) {
      throw new BadRequestException('Invalid category');
    }
  }

  private async validatePaymentTarget(
    userId: string,
    paymentMethod: PaymentMethod,
    cashAccountId: string | null | undefined,
    creditCardId: string | null | undefined,
  ): Promise<void> {
    if (cashAccountId && paymentMethod !== PaymentMethod.CASH) {
      throw new BadRequestException('Cash account requires cash payment method');
    }
    if (creditCardId && paymentMethod !== PaymentMethod.CARD_CREDIT) {
      throw new BadRequestException('Credit card requires credit card payment method');
    }
    if (paymentMethod === PaymentMethod.CARD_CREDIT && !creditCardId) {
      throw new BadRequestException('A credit card is required for recurring credit card expenses');
    }
    if (cashAccountId) {
      const account = await this.cashAccountRepo.findOne({ where: { id: cashAccountId, userId } });
      if (!account) throw new BadRequestException('Invalid cash account');
    }
    if (creditCardId) {
      const card = await this.creditCardRepo.findOne({ where: { id: creditCardId, userId } });
      if (!card) throw new BadRequestException('Invalid credit card');
    }
  }

  private validateExecutionDay(frequency: RecurringFrequency, executionDay: number): void {
    const isWeekdayFrequency =
      frequency === RecurringFrequency.WEEKLY || frequency === RecurringFrequency.BIWEEKLY;
    if (isWeekdayFrequency && executionDay > 7) {
      throw new BadRequestException('Weekly recurring expenses use a weekday from 1 to 7');
    }
  }

  private today(): Date {
    return dateOnly(new Date());
  }

  private errorMessage(error: unknown): string {
    if (error instanceof Error) return error.message.slice(0, 500);
    return String(error).slice(0, 500);
  }
}
