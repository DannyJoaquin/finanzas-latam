import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { Category } from '../categories/category.entity';

export enum BudgetPeriod {
  WEEKLY = 'weekly',
  BIWEEKLY = 'biweekly',
  MONTHLY = 'monthly',
}

@Index('idx_budgets_user_period', ['userId', 'periodStart', 'periodEnd'])
@Index('idx_budgets_category', ['userId', 'categoryId'])
@Entity('budgets')
export class Budget {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.budgets)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'category_id', nullable: true })
  categoryId: string;

  @ManyToOne(() => Category, { nullable: true })
  @JoinColumn({ name: 'category_id' })
  category: Category;

  @Column({ length: 100, nullable: true })
  name: string;

  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  @Column({ name: 'period_type', type: 'enum', enum: BudgetPeriod })
  periodType: BudgetPeriod;

  @Column({ name: 'period_start', type: 'date' })
  periodStart: Date;

  @Column({ name: 'period_end', type: 'date' })
  periodEnd: Date;

  @Column({ name: 'alert_50_sent', default: false })
  alert50Sent: boolean;

  @Column({ name: 'alert_80_sent', default: false })
  alert80Sent: boolean;

  @Column({ name: 'alert_100_sent', default: false })
  alert100Sent: boolean;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ name: 'is_dynamic', default: false })
  isDynamic: boolean;

  @Column({ name: 'dynamic_pct', type: 'decimal', precision: 5, scale: 2, nullable: true })
  dynamicPct: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
