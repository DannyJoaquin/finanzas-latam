import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { SharedExpense } from './shared-expense.entity';
import { User } from '../../users/user.entity';

export enum ApprovalStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

/**
 * Tracks the owner's approval decision for a shared expense that was created
 * in a group with `requiresApproval = true`.
 */
@Entity('shared_expense_approvals')
export class SharedExpenseApproval {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'expense_id', unique: true })
  expenseId: string;

  @ManyToOne(() => SharedExpense, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'expense_id' })
  expense: SharedExpense;

  /** The user who made the approval decision (group owner) */
  @Column({ name: 'reviewer_id' })
  reviewerId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'reviewer_id' })
  reviewer: User;

  @Column({
    type: 'enum',
    enum: ApprovalStatus,
    default: ApprovalStatus.PENDING,
  })
  status: ApprovalStatus;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
