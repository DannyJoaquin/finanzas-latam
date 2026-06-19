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

export enum SharedGroupMemberStatus {
  ACTIVE = 'active',
  REMOVED = 'removed',
  LEFT = 'left',
}

@Index('idx_shared_group_members_user', ['userId'])
@Entity('shared_group_members')
export class SharedGroupMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'group_id' })
  groupId: string;

  @ManyToOne(() => SharedGroup, (g) => g.members)
  @JoinColumn({ name: 'group_id' })
  group: SharedGroup;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({
    type: 'enum',
    enum: SharedGroupMemberStatus,
    default: SharedGroupMemberStatus.ACTIVE,
  })
  status: SharedGroupMemberStatus;

  @CreateDateColumn({ name: 'joined_at' })
  joinedAt: Date;
}
