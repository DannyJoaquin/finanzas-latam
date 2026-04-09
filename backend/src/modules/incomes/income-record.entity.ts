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
import { Income } from './income.entity';

@Index('idx_income_records_user_date', ['userId', 'receivedAt'])
@Entity('income_records')
export class IncomeRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'income_id' })
  incomeId: string;

  @ManyToOne(() => Income, (i) => i.records)
  @JoinColumn({ name: 'income_id' })
  income: Income;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  @Column({ name: 'received_at', type: 'date' })
  receivedAt: Date;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
