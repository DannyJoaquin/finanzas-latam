import {
  Column,
  CreateDateColumn,
  DeleteDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Exclude } from 'class-transformer';
import { Income } from '../incomes/income.entity';
import { Expense } from '../expenses/expense.entity';
import { Category } from '../categories/category.entity';
import { Budget } from '../budgets/budget.entity';
import { Goal } from '../goals/goal.entity';
import { CashAccount } from '../cash/cash-account.entity';
import { Insight } from '../insights/insight.entity';
import { Rule } from '../rules/rule.entity';

export enum PayCycle {
  WEEKLY = 'weekly',
  BIWEEKLY = 'biweekly',
  MONTHLY = 'monthly',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 255 })
  email: string;

  @Column({ length: 20, nullable: true })
  phone: string;

  @Column({ name: 'password_hash', length: 255, nullable: true })
  @Exclude()
  passwordHash: string | null;

  @Column({ name: 'full_name', length: 150 })
  fullName: string;

  @Column({ name: 'avatar_url', type: 'text', nullable: true })
  avatarUrl: string;

  @Column({ name: 'country_code', type: 'char', length: 2, default: 'HN' })
  countryCode: string;

  @Column({ type: 'char', length: 3, default: 'HNL' })
  currency: string;

  @Column({
    name: 'pay_cycle',
    type: 'enum',
    enum: PayCycle,
    default: PayCycle.BIWEEKLY,
  })
  payCycle: PayCycle;

  @Column({ name: 'pay_day_1', type: 'smallint', nullable: true })
  payDay1: number;

  @Column({ name: 'pay_day_2', type: 'smallint', nullable: true })
  payDay2: number;

  @Column({ length: 60, default: 'America/Tegucigalpa' })
  timezone: string;

  @Column({ name: 'biometric_enabled', default: false })
  biometricEnabled: boolean;

  @Column({ name: 'pin_hash', length: 255, nullable: true })
  @Exclude()
  pinHash: string;

  @Column({ name: 'fcm_token', type: 'text', nullable: true })
  fcmToken: string;

  @Column({ name: 'email_verified', default: false })
  emailVerified: boolean;

  // OAuth provider fields (null for email/password users)
  @Column({ length: 50, nullable: true })
  provider: string | null;

  @Column({ name: 'provider_id', length: 255, nullable: true })
  providerId: string | null;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', nullable: true })
  deletedAt: Date;

  @OneToMany(() => Income, (income) => income.user)
  incomes: Income[];

  @OneToMany(() => Expense, (expense) => expense.user)
  expenses: Expense[];

  @OneToMany(() => Category, (cat) => cat.user)
  categories: Category[];

  @OneToMany(() => Budget, (b) => b.user)
  budgets: Budget[];

  @OneToMany(() => Goal, (g) => g.user)
  goals: Goal[];

  @OneToMany(() => CashAccount, (ca) => ca.user)
  cashAccounts: CashAccount[];

  @OneToMany(() => Insight, (i) => i.user)
  insights: Insight[];

  @OneToMany(() => Rule, (r) => r.user)
  rules: Rule[];
}
