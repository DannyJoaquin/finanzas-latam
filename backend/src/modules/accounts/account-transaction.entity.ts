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
import { Account } from './account.entity';
import { Expense } from '../expenses/expense.entity';

export enum AccountTxType {
  DEPOSIT = 'deposit',
  WITHDRAW = 'withdraw',
  SPEND = 'spend',
  RECEIVE_TRANSFER = 'receive_transfer',
  SEND_TRANSFER = 'send_transfer',
}

@Index('idx_account_tx_account_date', ['accountId', 'date'])
@Entity('account_transactions')
export class AccountTransaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'account_id' })
  accountId: string;

  @ManyToOne(() => Account, (a) => a.transactions)
  @JoinColumn({ name: 'account_id' })
  account: Account;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: AccountTxType })
  type: AccountTxType;

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
