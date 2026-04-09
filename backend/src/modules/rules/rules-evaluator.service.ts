import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Rule, RuleTrigger } from './rule.entity';
import { Expense } from '../expenses/expense.entity';

type Condition = { field: string; op: string; value: unknown };
type Action = { type: string; params: Record<string, unknown> };

@Injectable()
export class RulesEvaluatorService {
  constructor(
    @InjectRepository(Rule)
    private ruleRepo: Repository<Rule>,
  ) {}

  async evaluateOnExpense(expense: Expense): Promise<Action[]> {
    const rules = await this.ruleRepo.find({
      where: { userId: expense.userId, isActive: true, triggerType: RuleTrigger.EXPENSE_ADDED },
      order: { priority: 'ASC' },
    });

    const triggeredActions: Action[] = [];
    for (const rule of rules) {
      if (this.evaluateConditions(rule.conditions, expense)) {
        triggeredActions.push(...rule.actions);
        rule.lastTriggered = new Date();
        await this.ruleRepo.save(rule);
      }
    }
    return triggeredActions;
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
