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

export enum MappingMatchType {
  EXACT = 'exact',
  PARTIAL = 'partial',
  LEARNED = 'learned',
}

@Index('idx_ucm_user_text', ['userId', 'normalizedText'])
@Entity('user_category_mappings')
export class UserCategoryMapping {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  /** Normalized version of the description used for fast lookup */
  @Column({ name: 'normalized_text', length: 255 })
  normalizedText: string;

  /** Original description as entered by the user */
  @Column({ name: 'original_text', length: 255 })
  originalText: string;

  @Column({ name: 'category_id' })
  categoryId: string;

  @ManyToOne(() => Category, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'category_id' })
  category: Category;

  @Column({
    name: 'match_type',
    type: 'enum',
    enum: MappingMatchType,
    default: MappingMatchType.LEARNED,
  })
  matchType: MappingMatchType;

  /** How many times this mapping has been used/confirmed */
  @Column({ name: 'usage_count', type: 'int', default: 1 })
  usageCount: number;

  /**
   * true if the user explicitly confirmed "remember this" or if usageCount
   * reached learningAutoConfirmThreshold.
   */
  @Column({ name: 'is_confirmed', default: false })
  isConfirmed: boolean;

  @Column({ name: 'last_used_at', type: 'timestamp', nullable: true })
  lastUsedAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
