import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { Category } from '../categories/category.entity';
import { Account } from '../accounts/account.entity';
import { CreditCard } from '../credit-cards/credit-card.entity';
import type { Expense, PaymentMethod } from '../expenses/expense.entity';

const PAYMENT_METHOD_VALUES = ['cash', 'card_credit', 'card_debit', 'transfer', 'other'];

export enum RecurringFrequency {
  DAILY = 'daily',
  WEEKLY = 'weekly',
  BIWEEKLY = 'biweekly',
  MONTHLY = 'monthly',
  BIMONTHLY = 'bimonthly',
  QUARTERLY = 'quarterly',
  SEMIANNUAL = 'semiannual',
  ANNUAL = 'annual',
}

@Index('idx_recurring_expenses_user_active_next', ['userId', 'isActive', 'nextRunDate'])
@Entity('recurring_expenses')
export class RecurringExpense {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ length: 150 })
  name: string;

  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'char', length: 3, default: 'HNL' })
  currency: string;

  @Column({ name: 'category_id' })
  categoryId: string;

  @ManyToOne(() => Category, { nullable: false })
  @JoinColumn({ name: 'category_id' })
  category: Category;

  @Column({
    name: 'payment_method',
    type: 'enum',
    enum: PAYMENT_METHOD_VALUES,
    default: 'cash',
  })
  paymentMethod: PaymentMethod;

  @Column({ name: 'cash_account_id', nullable: true })
  cashAccountId: string | null;

  @ManyToOne(() => Account, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'cash_account_id' })
  cashAccount: Account | null;

  @Column({ name: 'credit_card_id', nullable: true })
  creditCardId: string | null;

  @ManyToOne(() => CreditCard, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'credit_card_id' })
  creditCard: CreditCard | null;

  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @Column({ type: 'enum', enum: RecurringFrequency })
  frequency: RecurringFrequency;

  /** Day of month (1-31), or ISO weekday (1-7) for weekly schedules. */
  @Column({ name: 'execution_day', type: 'smallint' })
  executionDay: number;

  @Column({ name: 'start_date', type: 'date' })
  startDate: Date;

  @Column({ name: 'next_run_date', type: 'date' })
  nextRunDate: Date;

  @Column({ name: 'last_generated_date', type: 'date', nullable: true })
  lastGeneratedDate: Date | null;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ name: 'paused_at', type: 'timestamptz', nullable: true })
  pausedAt: Date | null;

  @Column({ name: 'last_generation_attempt_at', type: 'timestamptz', nullable: true })
  lastGenerationAttemptAt: Date | null;

  @Column({ name: 'last_generation_error', type: 'text', nullable: true })
  lastGenerationError: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany('Expense', (expense: Expense) => expense.recurringExpense)
  expenses: Expense[];
}
