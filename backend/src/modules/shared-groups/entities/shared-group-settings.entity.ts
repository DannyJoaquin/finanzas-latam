import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { SharedGroup } from './shared-group.entity';

/**
 * Per-group settings controlled by the group owner.
 * Created on-demand (not every group has a row — defaults apply when missing).
 */
@Entity('shared_group_settings')
export class SharedGroupSettings {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'group_id', unique: true })
  groupId: string;

  @OneToOne(() => SharedGroup, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'group_id' })
  group: SharedGroup;

  /**
   * When true, new expenses start in 'pending' status and require the
   * group owner to approve before they count towards balances.
   */
  @Column({ name: 'requires_approval', default: false })
  requiresApproval: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
