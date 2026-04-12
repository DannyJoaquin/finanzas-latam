import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { CreditCard } from './credit-card.entity';
import { User } from '../users/user.entity';

@Entity('credit_card_payments')
export class CreditCardPayment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'card_id' })
  cardId: string;

  @ManyToOne(() => CreditCard)
  @JoinColumn({ name: 'card_id' })
  card: CreditCard;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  /** Amount paid */
  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  /** The billing cycle start date this payment covers (YYYY-MM-DD) */
  @Column({ name: 'cycle_start', type: 'date' })
  cycleStart: string;

  /** The billing cycle end date this payment covers (YYYY-MM-DD) */
  @Column({ name: 'cycle_end', type: 'date' })
  cycleEnd: string;

  /** Date the payment was made */
  @Column({ name: 'payment_date', type: 'date' })
  paymentDate: string;

  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
