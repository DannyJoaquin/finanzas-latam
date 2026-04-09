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
import { CashTransaction } from './cash-transaction.entity';

@Entity('cash_accounts')
export class CashAccount {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.cashAccounts)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ length: 100 })
  name: string;

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

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @OneToMany(() => CashTransaction, (tx) => tx.cashAccount)
  transactions: CashTransaction[];
}
