import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreditCard } from './credit-card.entity';
import { CreditCardPayment } from './credit-card-payment.entity';
import { Expense } from '../expenses/expense.entity';
import { CreateCreditCardDto, UpdateCreditCardDto, RecordCardPaymentDto } from './dto/credit-card.dto';

@Injectable()
export class CreditCardsService {
  constructor(
    @InjectRepository(CreditCard)
    private cardRepo: Repository<CreditCard>,
    @InjectRepository(CreditCardPayment)
    private paymentRepo: Repository<CreditCardPayment>,
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

  async recordPayment(userId: string, cardId: string, dto: RecordCardPaymentDto): Promise<CreditCardPayment> {
    await this.findOne(userId, cardId);
    const payment = this.paymentRepo.create({
      cardId,
      userId,
      amount: dto.amount,
      cycleStart: dto.cycleStart,
      cycleEnd: dto.cycleEnd,
      paymentDate: dto.paymentDate,
      notes: dto.notes ?? null,
    });
    return this.paymentRepo.save(payment);
  }

  async getPaymentsForCard(userId: string, cardId: string): Promise<CreditCardPayment[]> {
    await this.findOne(userId, cardId);
    return this.paymentRepo.find({
      where: { cardId, userId },
      order: { paymentDate: 'DESC' },
    });
  }

  // ── private helpers ───────────────────────────────────────────────────────

  private async buildCardSummary(card: CreditCard, userId: string, today: Date) {
    const cycle = this.computeBillingCycle(card.cutOffDay, today);

    const openStart = this.toDateStr(cycle.currentStart);
    const todayStr = this.toDateStr(today);
    const cycleEndStr = this.toDateStr(cycle.currentEnd);

    const currentSplit = await this.getCardBalanceSplit(card.id, userId, openStart, todayStr);
    const currentBalance = currentSplit.hnl + currentSplit.usd;

    const paymentDueDate = new Date(cycle.currentEnd);
    paymentDueDate.setDate(paymentDueDate.getDate() + card.paymentDueDays);

    let overdueBalance = 0;
    let overdueBalanceHNL = 0;
    let overdueBalanceUSD = 0;
    let closedCyclePaymentDue: string | null = null;
    let daysUntilClosedPayment: number | null = null;
    let closedCycleStart: string | null = null;
    let closedCycleEnd: string | null = null;
    let closedCyclePaidAmount: number | null = null;
    let closedCyclePaidDate: string | null = null;

    if (cycle.previousCycle) {
      const prevStart = this.toDateStr(cycle.previousCycle.start);
      const prevEnd = this.toDateStr(cycle.previousCycle.end);
      const overdueSplit = await this.getCardBalanceSplit(card.id, userId, prevStart, prevEnd);
      overdueBalance = overdueSplit.hnl + overdueSplit.usd;
      overdueBalanceHNL = overdueSplit.hnl;
      overdueBalanceUSD = overdueSplit.usd;
      const closedPayDate = new Date(cycle.previousCycle.end);
      closedPayDate.setDate(closedPayDate.getDate() + card.paymentDueDays);
      closedCyclePaymentDue = this.toDateStr(closedPayDate);
      daysUntilClosedPayment = this.daysBetween(today, closedPayDate);
      closedCycleStart = prevStart;
      closedCycleEnd = prevEnd;

      // Sum all payments recorded for this closed cycle
      const cyclePayments = await this.paymentRepo.find({
        where: { cardId: card.id, userId, cycleStart: prevStart, cycleEnd: prevEnd },
        order: { createdAt: 'DESC' },
      });
      if (cyclePayments.length > 0) {
        closedCyclePaidAmount = cyclePayments.reduce((sum, p) => sum + Number(p.amount), 0);
        closedCyclePaidDate = cyclePayments[0].paymentDate;
      }
    }

    // Most recent payment for this card (any cycle)
    const lastPaymentRecord = await this.paymentRepo.findOne({
      where: { cardId: card.id, userId },
      order: { createdAt: 'DESC' },
    });
    const lastPaymentAmount = lastPaymentRecord ? Number(lastPaymentRecord.amount) : null;
    const lastPaymentDate = lastPaymentRecord?.paymentDate ?? null;

    // Payment status — ONLY reflects the closed cycle debt, never the open active cycle.
    // Current cycle spending is not "due" until the cycle closes.
    let paymentStatus: 'paid' | 'partial' | 'unpaid' | 'no_debt';
    let paymentCoverage: number | null = null;

    if (overdueBalance > 0) {
      // Previous cycle has unpaid balance — evaluate how much was covered
      if (closedCyclePaidAmount === null) {
        paymentStatus = 'unpaid';
      } else {
        const coverage = Math.min(100, Math.round((closedCyclePaidAmount / overdueBalance) * 100));
        paymentCoverage = coverage;
        paymentStatus = coverage >= 100 ? 'paid' : 'partial';
      }
    } else {
      // No closed-cycle debt — current cycle is active and nothing is due yet
      paymentStatus = 'no_debt';
    }

    const creditLimit = card.creditLimit ? Number(card.creditLimit) : null;
    // Net unpaid HNL balance — used for utilization % (limit is in HNL)
    const unpaidOverdueHNL = closedCyclePaidAmount !== null
      ? Math.max(0, overdueBalanceHNL - closedCyclePaidAmount)
      : overdueBalanceHNL;
    const totalUsedHNL = currentSplit.hnl + unpaidOverdueHNL;
    const utilizationPct =
      creditLimit && creditLimit > 0
        ? Math.min(100, Math.round((totalUsedHNL / creditLimit) * 100))
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
      currentBalanceHNL: currentSplit.hnl,
      currentBalanceUSD: currentSplit.usd,
      overdueBalance,
      overdueBalanceHNL,
      overdueBalanceUSD,
      closedCyclePaymentDue,
      daysUntilClosedPayment,
      closedCycleStart,
      closedCycleEnd,
      closedCyclePaidAmount,
      closedCyclePaidDate,
      lastPaymentAmount,
      lastPaymentDate,
      paymentStatus,
      paymentCoverage,
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

  private async getCardBalanceSplit(
    cardId: string,
    userId: string,
    start: string,
    end: string,
  ): Promise<{ hnl: number; usd: number }> {
    const rows = await this.expenseRepo
      .createQueryBuilder('e')
      .select('e.currency', 'currency')
      .addSelect('COALESCE(SUM(e.amount), 0)', 'total')
      .where(
        'e.creditCardId = :cardId AND e.userId = :userId AND e.date BETWEEN :start AND :end',
        { cardId, userId, start, end },
      )
      .groupBy('e.currency')
      .getRawMany<{ currency: string; total: string }>();

    return {
      hnl: parseFloat(rows.find((r) => r.currency === 'HNL')?.total ?? '0'),
      usd: parseFloat(rows.find((r) => r.currency === 'USD')?.total ?? '0'),
    };
  }

  private toDateStr(d: Date): string {
    return d.toISOString().split('T')[0];
  }

  private daysBetween(a: Date, b: Date): number {
    return Math.max(0, Math.ceil((b.getTime() - a.getTime()) / (1000 * 60 * 60 * 24)));
  }
}
