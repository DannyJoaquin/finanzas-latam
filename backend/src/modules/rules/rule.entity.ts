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

export enum RuleTrigger {
  EXPENSE_ADDED = 'expense_added',
  BUDGET_THRESHOLD = 'budget_threshold',
  INCOME_RECEIVED = 'income_received',
  GOAL_MILESTONE = 'goal_milestone',
  PERIODIC = 'periodic',
}

@Index('idx_rules_user_active', ['userId', 'isActive'])
@Entity('rules')
export class Rule {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.rules)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ length: 150 })
  name: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ name: 'trigger_type', type: 'enum', enum: RuleTrigger })
  triggerType: RuleTrigger;

  @Column({ type: 'jsonb' })
  conditions: Array<{ field: string; op: string; value: unknown }>;

  @Column({ type: 'jsonb' })
  actions: Array<{ type: string; params: Record<string, unknown> }>;

  @Column({ type: 'smallint', default: 1 })
  priority: number;

  @Column({ name: 'last_triggered', type: 'timestamptz', nullable: true })
  lastTriggered: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
