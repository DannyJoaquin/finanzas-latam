import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { CashAccount } from './cash-account.entity';
import { Expense } from '../expenses/expense.entity';

export enum CashTxType {
  DEPOSIT = 'deposit',
  WITHDRAW = 'withdraw',
  SPEND = 'spend',
  RECEIVE_TRANSFER = 'receive_transfer',
  SEND_TRANSFER = 'send_transfer',
}

@Index('idx_cash_tx_account_date', ['cashAccountId', 'date'])
@Entity('cash_transactions')
export class CashTransaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'cash_account_id' })
  cashAccountId: string;

  @ManyToOne(() => CashAccount, (ca) => ca.transactions)
  @JoinColumn({ name: 'cash_account_id' })
  cashAccount: CashAccount;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: CashTxType })
  type: CashTxType;

  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  @Column({ length: 255, nullable: true })
  description: string;

  @Column({ name: 'expense_id', nullable: true })
  expenseId: string;

  @ManyToOne(() => Expense, { nullable: true })
  @JoinColumn({ name: 'expense_id' })
  expense: Expense;

  @Column({ type: 'date' })
  date: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
