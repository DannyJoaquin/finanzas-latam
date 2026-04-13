import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Budget } from '../modules/budgets/budget.entity';
import { BudgetsService } from '../modules/budgets/budgets.service';
import { Expense } from '../modules/expenses/expense.entity';
import { User } from '../modules/users/user.entity';
import { PushNotificationService } from '../common/services/push-notification.service';
import { NotificationPreferencesService } from '../modules/users/notification-preferences.service';

@Injectable()
export class BudgetAlertsJob {
  private readonly logger = new Logger(BudgetAlertsJob.name);

  constructor(
    @InjectRepository(Budget)
    private budgetRepo: Repository<Budget>,
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
    private budgetsService: BudgetsService,
    private pushService: PushNotificationService,
    private notificationPrefsService: NotificationPreferencesService,
  ) {}

  /** Runs every hour */
  @Cron('0 * * * *')
  async run(): Promise<void> {
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
        const pctBefore = this.thresholdReached(budget);
        await this.budgetsService.checkAndMarkAlerts(budget, spent);
        const pctAfter = this.thresholdReached(budget);

        // Only send a push when a new threshold was just crossed
        if (pctAfter > pctBefore) {
          await this.sendBudgetPush(budget, pctAfter);
        }
      } catch (err) {
        this.logger.error(`Budget alert check failed for budget ${budget.id}`, err);
      }
    }
  }

  /** Returns the highest threshold percentage currently marked on the budget */
  private thresholdReached(budget: Budget): number {
    if (budget.alert100Sent) return 100;
    if (budget.alert80Sent) return 80;
    if (budget.alert50Sent) return 50;
    return 0;
  }

  private async sendBudgetPush(budget: Budget, pct: number): Promise<void> {
    try {
      const user = await this.userRepo.findOne({
        where: { id: budget.userId },
        select: ['id', 'fcmToken'],
      });
      if (!user?.fcmToken) return;

      // Respect user push preference for budget alerts
      const prefs = await this.notificationPrefsService.findOrCreateDefaults(user.id);
      if (!prefs.pushBudgetAlerts) return;

      const label = pct >= 100 ? 'agotado' : `al ${pct}%`;
      await this.pushService.send({
        userId: user.id,
        fcmToken: user.fcmToken,
        title: `Presupuesto ${label}`,
        body: `Tu presupuesto "${budget.name}" ha llegado ${label}. Revisa tus gastos.`,
        data: { type: 'budget_alert', budgetId: budget.id, pct: String(pct) },
      });
    } catch (err) {
      this.logger.error(`Could not send budget push for budget ${budget.id}`, err);
    }
  }
}
