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
import { Category } from '../categories/category.entity';
import type { CategorizationConfidence, CategorizationSource } from './interfaces/categorization-result.interface';

@Index('idx_cal_user_created', ['userId', 'createdAt'])
@Index('idx_cal_expense', ['expenseId'])
@Entity('categorization_audit_logs')
export class CategorizationAuditLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  /** Set once the expense is persisted. Null for pre-save suggestions. */
  @Column({ name: 'expense_id', type: 'uuid', nullable: true })
  expenseId: string | null;

  /** Original description as entered by the user */
  @Column({ name: 'description', type: 'text', nullable: true })
  description: string | null;

  @Column({ name: 'suggested_category_id', type: 'uuid', nullable: true })
  suggestedCategoryId: string | null;

  @ManyToOne(() => Category, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'suggested_category_id' })
  suggestedCategory: Category;

  /** Updated when the user changes the category after the fact */
  @Column({ name: 'final_category_id', type: 'uuid', nullable: true })
  finalCategoryId: string | null;

  @ManyToOne(() => Category, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'final_category_id' })
  finalCategory: Category;

  @Column({ name: 'confidence', type: 'varchar', length: 10, default: 'none' })
  confidence: CategorizationConfidence;

  @Column({ name: 'source', type: 'varchar', length: 30, default: 'none' })
  source: CategorizationSource;

  /** The keyword/merchant that matched — for debugging */
  @Column({ name: 'matched_keyword', type: 'varchar', length: 100, nullable: true })
  matchedKeyword: string | null;

  /** Whether the backend auto-assigned the category (vs just suggested) */
  @Column({ name: 'was_auto_assigned', default: false })
  wasAutoAssigned: boolean;

  /** Whether the user changed the auto-assigned/suggested category afterward */
  @Column({ name: 'was_corrected', default: false })
  wasCorrected: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
