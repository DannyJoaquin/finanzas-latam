import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreditCard } from './credit-card.entity';
import { Expense } from '../expenses/expense.entity';
import { CreateCreditCardDto, UpdateCreditCardDto } from './dto/credit-card.dto';

@Injectable()
export class CreditCardsService {
  constructor(
    @InjectRepository(CreditCard)
    private cardRepo: Repository<CreditCard>,
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
  ) {}

  findAll(userId: string): Promise<CreditCard[]> {
    return this.cardRepo.find({
      where: { userId, isActive: true },
      order: { createdAt: 'ASC' },
    });
  }

  async findOne(userId: string, id: string): Promise<CreditCard> {
    const card = await this.cardRepo.findOne({ where: { id, userId } });
    if (!card) throw new NotFoundException('Credit card not found');
    return card;
  }

  async create(userId: string, dto: CreateCreditCardDto): Promise<CreditCard> {
    const card = this.cardRepo.create({
      ...dto,
      userId,
      paymentDueDays: dto.paymentDueDays ?? 20,
    });
    return this.cardRepo.save(card);
  }

  async update(userId: string, id: string, dto: UpdateCreditCardDto): Promise<CreditCard> {
    const card = await this.findOne(userId, id);
    Object.assign(card, dto);
    return this.cardRepo.save(card);
  }

  async remove(userId: string, id: string): Promise<void> {
    const card = await this.findOne(userId, id);
    card.isActive = false;
    await this.cardRepo.save(card);
  }

  async getSummary(userId: string) {
    const cards = await this.findAll(userId);
    const today = new Date();
    return Promise.all(cards.map((card) => this.buildCardSummary(card, userId, today)));
  }

  // ── private helpers ───────────────────────────────────────────────────────

  private async buildCardSummary(card: CreditCard, userId: string, today: Date) {
    const cycle = this.computeBillingCycle(card.cutOffDay, today);

    const openStart = this.toDateStr(cycle.currentStart);
    const todayStr = this.toDateStr(today);
    const cycleEndStr = this.toDateStr(cycle.currentEnd);

    const currentBalance = await this.getCardBalance(card.id, userId, openStart, todayStr);

    const paymentDueDate = new Date(cycle.currentEnd);
    paymentDueDate.setDate(paymentDueDate.getDate() + card.paymentDueDays);

    let overdueBalance = 0;
    let closedCyclePaymentDue: string | null = null;
    let daysUntilClosedPayment: number | null = null;

    if (cycle.previousCycle) {
      const prevStart = this.toDateStr(cycle.previousCycle.start);
      const prevEnd = this.toDateStr(cycle.previousCycle.end);
      overdueBalance = await this.getCardBalance(card.id, userId, prevStart, prevEnd);
      const closedPayDate = new Date(cycle.previousCycle.end);
      closedPayDate.setDate(closedPayDate.getDate() + card.paymentDueDays);
      closedCyclePaymentDue = this.toDateStr(closedPayDate);
      daysUntilClosedPayment = this.daysBetween(today, closedPayDate);
    }

    const creditLimit = card.creditLimit ? Number(card.creditLimit) : null;
    const utilizationPct =
      creditLimit && creditLimit > 0
        ? Math.round((currentBalance / creditLimit) * 100)
        : null;

    return {
      id: card.id,
      name: card.name,
      network: card.network,
      color: card.color,
      creditLimit,
      limitCurrency: card.limitCurrency ?? 'HNL',
      cutOffDay: card.cutOffDay,
      paymentDueDays: card.paymentDueDays,
      currentCycleStart: this.toDateStr(cycle.currentStart),
      currentCycleEnd: cycleEndStr,
      nextCutOffDate: cycleEndStr,
      paymentDueDate: this.toDateStr(paymentDueDate),
      daysUntilCutOff: cycle.daysUntilCutOff,
      daysUntilPayment: this.daysBetween(today, paymentDueDate),
      currentBalance,
      overdueBalance,
      closedCyclePaymentDue,
      daysUntilClosedPayment,
      utilizationPct,
    };
  }

  private computeBillingCycle(cutOffDay: number, today: Date) {
    const year = today.getFullYear();
    const month = today.getMonth();
    const day = today.getDate();

    let currentStart: Date;
    let currentEnd: Date;
    let previousCycle: { start: Date; end: Date } | null = null;

    if (day <= cutOffDay) {
      const prevMonth = month === 0 ? 11 : month - 1;
      const prevYear = month === 0 ? year - 1 : year;
      currentStart = new Date(prevYear, prevMonth, cutOffDay + 1);
      currentEnd = new Date(year, month, cutOffDay);
    } else {
      currentStart = new Date(year, month, cutOffDay + 1);
      const nextMonth = month === 11 ? 0 : month + 1;
      const nextYear = month === 11 ? year + 1 : year;
      currentEnd = new Date(nextYear, nextMonth, cutOffDay);

      const prevMonth = month === 0 ? 11 : month - 1;
      const prevYear = month === 0 ? year - 1 : year;
      previousCycle = {
        start: new Date(prevYear, prevMonth, cutOffDay + 1),
        end: new Date(year, month, cutOffDay),
      };
    }

    return {
      currentStart,
      currentEnd,
      daysUntilCutOff: this.daysBetween(today, currentEnd),
      previousCycle,
    };
  }

  private async getCardBalance(
    cardId: string,
    userId: string,
    start: string,
    end: string,
  ): Promise<number> {
    const result = await this.expenseRepo
      .createQueryBuilder('e')
      .select('COALESCE(SUM(e.amount), 0)', 'total')
      .where(
        'e.creditCardId = :cardId AND e.userId = :userId AND e.date BETWEEN :start AND :end',
        { cardId, userId, start, end },
      )
      .getRawOne<{ total: string }>();
    return parseFloat(result?.total ?? '0');
  }

  private toDateStr(d: Date): string {
    return d.toISOString().split('T')[0];
  }

  private daysBetween(a: Date, b: Date): number {
    return Math.max(0, Math.ceil((b.getTime() - a.getTime()) / (1000 * 60 * 60 * 24)));
  }
}
