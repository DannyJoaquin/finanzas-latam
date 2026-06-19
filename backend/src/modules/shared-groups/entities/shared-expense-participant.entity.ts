import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../../users/user.entity';
import { SharedExpense } from './shared-expense.entity';

@Index('idx_sep_user', ['userId'])
@Entity('shared_expense_participants')
export class SharedExpenseParticipant {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'expense_id' })
  expenseId: string;

  @ManyToOne(() => SharedExpense, (e) => e.participants)
  @JoinColumn({ name: 'expense_id' })
  expense: SharedExpense;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'share_amount', type: 'numeric', precision: 12, scale: 2 })
  shareAmount: number;

  @Column({ name: 'is_settled', default: false })
  isSettled: boolean;
}
