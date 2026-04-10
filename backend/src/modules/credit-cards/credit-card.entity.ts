import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../users/user.entity';

export enum CardNetwork {
  VISA = 'visa',
  MASTERCARD = 'mastercard',
  AMEX = 'amex',
  OTHER = 'other',
}

@Entity('credit_cards')
export class CreditCard {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ length: 100 })
  name: string;

  @Column({
    type: 'enum',
    enum: CardNetwork,
    default: CardNetwork.OTHER,
  })
  network: CardNetwork;

  /** Day of month the billing cycle closes (1–28) */
  @Column({ name: 'cut_off_day', type: 'smallint' })
  cutOffDay: number;

  /** Days after the cut-off date the payment is due (e.g. 20) */
  @Column({ name: 'payment_due_days', type: 'smallint', default: 20 })
  paymentDueDays: number;

  /** Optional credit limit for utilisation % */
  @Column({ name: 'credit_limit', type: 'numeric', precision: 12, scale: 2, nullable: true })
  creditLimit: number | null;

  /** Currency of the credit limit: 'HNL' or 'USD' */
  @Column({ name: 'limit_currency', type: 'varchar', length: 3, default: 'HNL' })
  limitCurrency: string;

  /** Display colour hex, e.g. '#1A1F71' */
  @Column({ type: 'varchar', length: 7, nullable: true })
  color: string | null;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
