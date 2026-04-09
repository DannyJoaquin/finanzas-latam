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
import { GoalContribution } from './goal-contribution.entity';

export enum GoalStatus {
  ACTIVE = 'active',
  COMPLETED = 'completed',
  PAUSED = 'paused',
  CANCELLED = 'cancelled',
}

@Index('idx_goals_user_status', ['userId', 'status'])
@Entity('goals')
export class Goal {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.goals)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ length: 150 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ name: 'target_amount', type: 'numeric', precision: 12, scale: 2 })
  targetAmount: number;

  @Column({ name: 'current_amount', type: 'numeric', precision: 12, scale: 2, default: 0 })
  currentAmount: number;

  @Column({ type: 'char', length: 3, default: 'HNL' })
  currency: string;

  @Column({ name: 'target_date', type: 'date', nullable: true })
  targetDate: Date;

  @Column({ length: 50, nullable: true })
  icon: string;

  @Column({ type: 'char', length: 7, nullable: true })
  color: string;

  @Column({ type: 'enum', enum: GoalStatus, default: GoalStatus.ACTIVE })
  status: GoalStatus;

  @Column({ name: 'auto_save_pct', type: 'decimal', precision: 5, scale: 2, nullable: true })
  autoSavePct: number;

  @Column({ name: 'auto_save_fixed', type: 'numeric', precision: 12, scale: 2, nullable: true })
  autoSaveFixed: number;

  @Column({ type: 'smallint', default: 1 })
  priority: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => GoalContribution, (gc) => gc.goal)
  contributions: GoalContribution[];
}
