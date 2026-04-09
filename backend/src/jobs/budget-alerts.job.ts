import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThanOrEqual, Repository } from 'typeorm';
import { Budget } from '../modules/budgets/budget.entity';
import { BudgetsService } from '../modules/budgets/budgets.service';
import { Expense } from '../modules/expenses/expense.entity';

@Injectable()
export class BudgetAlertsJob {
  private readonly logger = new Logger(BudgetAlertsJob.name);

  constructor(
    @InjectRepository(Budget)
    private budgetRepo: Repository<Budget>,
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    private budgetsService: BudgetsService,
  ) {}

  /** Runs every hour */
  @Cron('0 * * * *')
  async run(): Promise<void> {
    const today = new Date().toISOString().split('T')[0];
    const activeBudgets = await this.budgetRepo.find({
      where: {
        isActive: true,
        alert100Sent: false,
      },
    });

    for (const budget of activeBudgets) {
      try {
        const result = await this.expenseRepo
          .createQueryBuilder('e')
          .select('COALESCE(SUM(e.amount), 0)', 'total')
          .where('e.user_id = :userId', { userId: budget.userId })
          .andWhere('e.date BETWEEN :start AND :end', {
            start: budget.periodStart,
            end: budget.periodEnd,
          })
          .andWhere(budget.categoryId ? 'e.category_id = :catId' : '1=1', { catId: budget.categoryId })
          .getRawOne<{ total: string }>();

        const spent = parseFloat(result?.total ?? '0');
        await this.budgetsService.checkAndMarkAlerts(budget, spent);
      } catch (err) {
        this.logger.error(`Budget alert check failed for budget ${budget.id}`, err);
      }
    }
  }
}
