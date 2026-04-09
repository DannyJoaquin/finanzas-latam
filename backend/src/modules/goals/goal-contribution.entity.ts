import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { Goal } from './goal.entity';

export enum ContributionSource {
  MANUAL = 'manual',
  AUTO_RULE = 'auto_rule',
  INCOME = 'income',
}

@Entity('goal_contributions')
export class GoalContribution {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'goal_id' })
  goalId: string;

  @ManyToOne(() => Goal, (g) => g.contributions)
  @JoinColumn({ name: 'goal_id' })
  goal: Goal;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'enum', enum: ContributionSource, default: ContributionSource.MANUAL })
  source: ContributionSource;

  @Column({ type: 'date' })
  date: Date;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
