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

export enum InsightType {
  SAVINGS_OPPORTUNITY = 'savings_opportunity',
  ANOMALY = 'anomaly',
  PROJECTION = 'projection',
  STREAK = 'streak',
  BUDGET_WARNING = 'budget_warning',
  PATTERN = 'pattern',
  ACHIEVEMENT = 'achievement',
}

export enum InsightPriority {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

@Index('idx_insights_user_unread', ['userId', 'isRead', 'isDismissed'])
@Index('idx_insights_type', ['userId', 'type'])
@Entity('insights')
export class Insight {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.insights)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: InsightType })
  type: InsightType;

  @Column({ type: 'enum', enum: InsightPriority, default: InsightPriority.MEDIUM })
  priority: InsightPriority;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text' })
  body: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, unknown>;

  @Column({ name: 'is_read', default: false })
  isRead: boolean;

  @Column({ name: 'is_dismissed', default: false })
  isDismissed: boolean;

  @CreateDateColumn({ name: 'generated_at' })
  generatedAt: Date;

  @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
  expiresAt: Date;
}
