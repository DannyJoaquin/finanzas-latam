import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Rule, RuleTrigger } from './rule.entity';
import { Expense } from '../expenses/expense.entity';
import { Insight, InsightPriority, InsightType } from '../insights/insight.entity';

type Condition = { field: string; op: string; value: unknown };
type Action = { type: string; params: Record<string, unknown> };

@Injectable()
export class RulesEvaluatorService {
  private readonly logger = new Logger(RulesEvaluatorService.name);

  constructor(
    @InjectRepository(Rule)
    private ruleRepo: Repository<Rule>,
    @InjectRepository(Expense)
    private expenseRepo: Repository<Expense>,
    @InjectRepository(Insight)
    private insightRepo: Repository<Insight>,
  ) {}

  async evaluateOnExpense(expense: Expense): Promise<Action[]> {
    const rules = await this.ruleRepo.find({
      where: { userId: expense.userId, isActive: true, triggerType: RuleTrigger.EXPENSE_ADDED },
      order: { priority: 'ASC' },
    });

    const triggeredActions: Action[] = [];
    for (const rule of rules) {
      if (this.evaluateConditions(rule.conditions, expense)) {
        const actions = Array.isArray(rule.actions) ? rule.actions : [];
        triggeredActions.push(...actions);
        await this.executeActions(expense, rule, actions);
        rule.lastTriggered = new Date();
        await this.ruleRepo.save(rule);
      }
    }
    return triggeredActions;
  }

  private async executeActions(
    expense: Expense,
    rule: Rule,
    actions: Action[],
  ): Promise<void> {
    let expenseChanged = false;

    for (const action of actions) {
      const params = action.params ?? {};

      if (action.type === 'notify') {
        const message = typeof params.message === 'string' && params.message.trim()
          ? params.message.trim()
          : `La regla "${rule.name}" se activó para ${expense.description || 'un gasto'}.`;
        await this.insightRepo.save(this.insightRepo.create({
          userId: expense.userId,
          type: InsightType.PATTERN,
          priority: InsightPriority.MEDIUM,
          title: `Regla activada: ${rule.name}`.slice(0, 200),
          body: message,
          metadata: {
            source: 'rule',
            ruleId: rule.id,
            expenseId: expense.id,
          },
          isRead: false,
          isDismissed: false,
        }));
        continue;
      }

      if (action.type === 'tag') {
        const rawTags = Array.isArray(params.tags)
          ? params.tags
          : [params.tag];
        const tags = rawTags
          .filter((tag): tag is string => typeof tag === 'string' && tag.trim().length > 0)
          .map((tag) => tag.trim());
        if (tags.length > 0) {
          expense.tags = [...new Set([...(expense.tags ?? []), ...tags])];
          expenseChanged = true;
        }
        continue;
      }

      if (action.type === 'auto_categorize' && typeof params.categoryId === 'string') {
        expense.categoryId = params.categoryId;
        expenseChanged = true;
        continue;
      }

      this.logger.debug(`Unsupported rule action "${action.type}" for rule ${rule.id}`);
    }

    if (expenseChanged) await this.expenseRepo.save(expense);
  }

  private evaluateConditions(conditions: Condition[], expense: Expense): boolean {
    return conditions.every((cond) => this.evaluateCondition(cond, expense));
  }

  private evaluateCondition(cond: Condition, expense: Expense): boolean {
    const fieldValue = this.getFieldValue(cond.field, expense);
    switch (cond.op) {
      case 'eq': return fieldValue === cond.value;
      case 'neq': return fieldValue !== cond.value;
      case 'gt': return Number(fieldValue) > Number(cond.value);
      case 'gte': return Number(fieldValue) >= Number(cond.value);
      case 'lt': return Number(fieldValue) < Number(cond.value);
      case 'lte': return Number(fieldValue) <= Number(cond.value);
      case 'contains':
        return typeof fieldValue === 'string' &&
          fieldValue.toLowerCase().includes(String(cond.value).toLowerCase());
      default: return false;
    }
  }

  private getFieldValue(field: string, expense: Expense): unknown {
    const map: Record<string, unknown> = {
      'amount': expense.amount,
      'paymentMethod': expense.paymentMethod,
      'description': expense.description,
      'categoryId': expense.categoryId,
    };
    return map[field] ?? null;
  }
}
