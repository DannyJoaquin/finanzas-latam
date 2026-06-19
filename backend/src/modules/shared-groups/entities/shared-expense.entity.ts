import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../../users/user.entity';
import { SharedGroup } from './shared-group.entity';
import { SharedExpenseParticipant } from './shared-expense-participant.entity';

export enum SharedExpensePaymentMethod {
  CASH = 'cash',
  CARD_CREDIT = 'card_credit',
  CARD_DEBIT = 'card_debit',
  TRANSFER = 'transfer',
  OTHER = 'other',
}

export enum SharedExpenseStatus {
  APPROVED = 'approved',
  PENDING = 'pending',
}

export enum RecurringInterval {
  MONTHLY = 'monthly',
  WEEKLY = 'weekly',
}

@Index('idx_shared_expenses_group', ['groupId'])
@Index('idx_shared_expenses_payer', ['payerId'])
@Entity('shared_expenses')
export class SharedExpense {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'group_id' })
  groupId: string;

  @ManyToOne(() => SharedGroup, (g) => g.expenses)
  @JoinColumn({ name: 'group_id' })
  group: SharedGroup;

  @Column({ name: 'payer_id' })
  payerId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'payer_id' })
  payer: User;

  @Column({ name: 'total_amount', type: 'numeric', precision: 12, scale: 2 })
  totalAmount: number;

  @Column({ type: 'char', length: 3, default: 'HNL' })
  currency: string;

  @Column({ length: 255 })
  description: string;

  @Column({ name: 'category_label', length: 100, nullable: true })
  categoryLabel: string;

  @Column({
    name: 'payment_method',
    type: 'enum',
    enum: SharedExpensePaymentMethod,
    default: SharedExpensePaymentMethod.CASH,
  })
  paymentMethod: SharedExpensePaymentMethod;

  @Column({ type: 'text', nullable: true })
  note: string;

  @Column({ type: 'date' })
  date: Date;

  // ── New feature fields ───────────────────────────────────────────────────

  @Column({ name: 'receipt_url', type: 'text', nullable: true })
  receiptUrl: string | null;

  @Column({
    name: 'status',
    type: 'enum',
    enum: SharedExpenseStatus,
    default: SharedExpenseStatus.APPROVED,
  })
  status: SharedExpenseStatus;

  @Column({ name: 'is_recurring', default: false })
  isRecurring: boolean;

  @Column({
    name: 'recurring_interval',
    type: 'enum',
    enum: RecurringInterval,
    nullable: true,
  })
  recurringInterval: RecurringInterval | null;

  /** Day-of-month (1–28) for monthly recurrence; day-of-week (1=Mon..7=Sun) for weekly */
  @Column({ name: 'recurring_day', type: 'smallint', nullable: true })
  recurringDay: number | null;

  @Column({ name: 'next_recurrence_at', type: 'timestamptz', nullable: true })
  nextRecurrenceAt: Date | null;

  @OneToMany(() => SharedExpenseParticipant, (p) => p.expense, { cascade: true })
  participants: SharedExpenseParticipant[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
