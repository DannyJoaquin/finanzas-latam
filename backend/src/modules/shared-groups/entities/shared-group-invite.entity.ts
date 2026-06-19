import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { SharedGroup } from './shared-group.entity';

@Entity('shared_group_invites')
export class SharedGroupInvite {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'group_id' })
  groupId: string;

  @ManyToOne(() => SharedGroup, (g) => g.invites)
  @JoinColumn({ name: 'group_id' })
  group: SharedGroup;

  @Column({ length: 8 })
  code: string;

  @Column({ name: 'max_uses', default: 50 })
  maxUses: number;

  @Column({ default: 0 })
  uses: number;

  @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
  expiresAt: Date;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
