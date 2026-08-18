import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { AccountTransaction } from './account-transaction.entity';

export enum AccountType {
  CASH = 'cash',
  CHECKING = 'checking',
  SAVINGS = 'savings',
  LOCKED_SAVINGS = 'locked_savings',
  PENSION = 'pension',
  OTHER = 'other',
}

@Entity('accounts')
export class Account {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.cashAccounts)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ length: 100 })
  name: string;

  @Column({ type: 'enum', enum: AccountType, default: AccountType.CASH })
  type: AccountType;

  @Column({ type: 'numeric', precision: 12, scale: 2, default: 0 })
  balance: number;

  @Column({ type: 'char', length: 3, default: 'HNL' })
  currency: string;

  @Column({ type: 'char', length: 7, nullable: true })
  color: string;

  @Column({ length: 50, nullable: true })
  icon: string;

  @Column({ name: 'is_default', default: false })
  isDefault: boolean;

  @Column({ name: 'sort_order', type: 'smallint', default: 0 })
  sortOrder: number;

  @Column({ type: 'varchar', length: 100, nullable: true })
  institution: string | null;

  // Whether this account's balance can be spent from (drives expense/income
  // account pickers and the Disponible bucket in net-worth computations).
  @Column({ name: 'is_available_for_expenses', default: true })
  isAvailableForExpenses: boolean;

  // Whether this account is currently locked (term deposits held until
  // maturity). Distinct from isAvailableForExpenses: a locked account still
  // shows a maturity countdown, while a pension account is simply never
  // spendable with no unlock concept at all.
  @Column({ name: 'is_locked', default: false })
  isLocked: boolean;

  @Column({ name: 'locked_until', type: 'date', nullable: true })
  lockedUntil: Date | null;

  @Column({
    name: 'interest_rate_annual',
    type: 'numeric',
    precision: 5,
    scale: 2,
    nullable: true,
  })
  interestRateAnnual: number | null;

  @Column({ name: 'opened_at', type: 'date', nullable: true })
  openedAt: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @OneToMany(() => AccountTransaction, (tx) => tx.account)
  transactions: AccountTransaction[];
}
