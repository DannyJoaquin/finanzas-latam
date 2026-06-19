import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../../users/user.entity';
import { SharedGroupMember } from './shared-group-member.entity';
import { SharedExpense } from './shared-expense.entity';
import { SharedGroupInvite } from './shared-group-invite.entity';
import { SharedSettlement } from './shared-settlement.entity';

@Index('idx_shared_groups_owner', ['ownerId'])
@Entity('shared_groups')
export class SharedGroup {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'owner_id' })
  ownerId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'owner_id' })
  owner: User;

  @Column({ length: 120 })
  name: string;

  @Column({ length: 300, nullable: true })
  description: string;

  @Column({ type: 'char', length: 3, default: 'HNL' })
  currency: string;

  @Column({ name: 'invite_code', length: 8, unique: true })
  inviteCode: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @OneToMany(() => SharedGroupMember, (m) => m.group)
  members: SharedGroupMember[];

  @OneToMany(() => SharedExpense, (e) => e.group)
  expenses: SharedExpense[];

  @OneToMany(() => SharedGroupInvite, (i) => i.group)
  invites: SharedGroupInvite[];

  @OneToMany(() => SharedSettlement, (s) => s.group)
  settlements: SharedSettlement[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
