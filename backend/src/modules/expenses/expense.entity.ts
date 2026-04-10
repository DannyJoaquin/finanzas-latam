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
import { CashAccount } from '../cash/cash-account.entity';
import { CreditCard } from '../credit-cards/credit-card.entity';

export enum PaymentMethod {
  CASH = 'cash',
  CARD_CREDIT = 'card_credit',
  CARD_DEBIT = 'card_debit',
  TRANSFER = 'transfer',
  OTHER = 'other',
}

export enum ExpenseSource {
  MANUAL = 'manual',
  VOICE = 'voice',
  OCR = 'ocr',
  SMS = 'sms',
  WHATSAPP = 'whatsapp',
  AUTO = 'auto',
}

@Index('idx_expenses_user_date', ['userId', 'date'])
@Index('idx_expenses_category', ['categoryId'])
@Index('idx_expenses_method', ['userId', 'paymentMethod'])
@Entity('expenses')
export class Expense {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.expenses)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'category_id', nullable: true })
  categoryId: string;

  @ManyToOne(() => Category, (cat) => cat.expenses, { nullable: true })
  @JoinColumn({ name: 'category_id' })
  category: Category;

  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'char', length: 3, default: 'HNL' })
  currency: string;

  @Column({ length: 255, nullable: true })
  description: string;

  @Column({
    name: 'payment_method',
    type: 'enum',
    enum: PaymentMethod,
    default: PaymentMethod.CASH,
  })
  paymentMethod: PaymentMethod;

  @Column({ type: 'date' })
  date: Date;

  @Column({ name: 'receipt_url', type: 'text', nullable: true })
  receiptUrl: string;

  @Column({ name: 'location_lat', type: 'decimal', precision: 9, scale: 6, nullable: true })
  locationLat: number;

  @Column({ name: 'location_lng', type: 'decimal', precision: 9, scale: 6, nullable: true })
  locationLng: number;

  @Column({ name: 'location_name', length: 200, nullable: true })
  locationName: string;

  @Column({ type: 'text', array: true, default: '{}' })
  tags: string[];

  @Column({ name: 'is_recurring', default: false })
  isRecurring: boolean;

  @Column({ name: 'cash_account_id', nullable: true })
  cashAccountId: string;

  @ManyToOne(() => CashAccount, { nullable: true })
  @JoinColumn({ name: 'cash_account_id' })
  cashAccount: CashAccount;

  @Column({ name: 'credit_card_id', nullable: true })
  creditCardId: string | null;

  @ManyToOne(() => CreditCard, { nullable: true })
  @JoinColumn({ name: 'credit_card_id' })
  creditCard: CreditCard | null;

  @Column({ type: 'enum', enum: ExpenseSource, default: ExpenseSource.MANUAL })
  source: ExpenseSource;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
