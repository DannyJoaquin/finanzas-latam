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
import { IncomeRecord } from './income-record.entity';

export enum IncomeType {
  SALARY = 'salary',
  VARIABLE = 'variable',
  REMITTANCE = 'remittance',
  FREELANCE = 'freelance',
  OTHER = 'other',
}

export enum IncomeCycle {
  WEEKLY = 'weekly',
  BIWEEKLY = 'biweekly',
  MONTHLY = 'monthly',
  ONE_TIME = 'one_time',
}

@Index('idx_incomes_user_active', ['user', 'isActive'])
@Entity('incomes')
export class Income {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.incomes)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'source_name', length: 150 })
  sourceName: string;

  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'char', length: 3, default: 'HNL' })
  currency: string;

  @Column({ type: 'enum', enum: IncomeType })
  type: IncomeType;

  @Column({ type: 'enum', enum: IncomeCycle })
  cycle: IncomeCycle;

  @Column({ name: 'pay_day_1', type: 'smallint', nullable: true })
  payDay1: number;

  @Column({ name: 'pay_day_2', type: 'smallint', nullable: true })
  payDay2: number;

  @Column({ name: 'next_expected_at', type: 'date', nullable: true })
  nextExpectedAt: Date;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => IncomeRecord, (r) => r.income)
  records: IncomeRecord[];
}
