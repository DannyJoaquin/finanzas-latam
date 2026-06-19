import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../../users/user.entity';
import { SharedGroup } from './shared-group.entity';

export enum SharedSettlementPaymentMethod {
  CASH = 'cash',
  TRANSFER = 'transfer',
  OTHER = 'other',
}

@Index('idx_shared_settlements_group', ['groupId'])
@Entity('shared_settlements')
export class SharedSettlement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'group_id' })
  groupId: string;

  @ManyToOne(() => SharedGroup, (g) => g.settlements)
  @JoinColumn({ name: 'group_id' })
  group: SharedGroup;

  @Column({ name: 'payer_id' })
  payerId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'payer_id' })
  payer: User;

  @Column({ name: 'receiver_id' })
  receiverId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'receiver_id' })
  receiver: User;

  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: number;

  @Column({
    name: 'payment_method',
    type: 'enum',
    enum: SharedSettlementPaymentMethod,
    default: SharedSettlementPaymentMethod.CASH,
  })
  paymentMethod: SharedSettlementPaymentMethod;

  @Column({ type: 'text', nullable: true })
  note: string;

  @Column({ type: 'date' })
  date: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
