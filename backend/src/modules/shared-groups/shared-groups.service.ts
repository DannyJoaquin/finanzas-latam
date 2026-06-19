import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  GoneException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomBytes } from 'crypto';
import { SharedGroup } from './entities/shared-group.entity';
import { SharedGroupMember, SharedGroupMemberStatus } from './entities/shared-group-member.entity';
import { SharedGroupInvite } from './entities/shared-group-invite.entity';
import { CreateGroupDto, JoinGroupDto } from './shared-groups.dto';

@Injectable()
export class SharedGroupsService {
  constructor(
    @InjectRepository(SharedGroup)
    private groupRepo: Repository<SharedGroup>,
    @InjectRepository(SharedGroupMember)
    private memberRepo: Repository<SharedGroupMember>,
    @InjectRepository(SharedGroupInvite)
    private inviteRepo: Repository<SharedGroupInvite>,
  ) {}

  // ── Groups ──────────────────────────────────────────────────────────────────

  async createGroup(userId: string, dto: CreateGroupDto): Promise<SharedGroup> {
    const inviteCode = this.generateCode();
    const group = this.groupRepo.create({
      ownerId: userId,
      name: dto.name,
      description: dto.description,
      currency: dto.currency ?? 'HNL',
      inviteCode,
    });
    const saved = await this.groupRepo.save(group);

    // Owner is auto-added as active member
    await this.memberRepo.save(
      this.memberRepo.create({ groupId: saved.id, userId, status: SharedGroupMemberStatus.ACTIVE }),
    );

    // Create a default invite (also using the same code for simplicity)
    await this.inviteRepo.save(
      this.inviteRepo.create({ groupId: saved.id, code: inviteCode }),
    );

    return saved;
  }

  async getUserGroups(userId: string): Promise<SharedGroup[]> {
    // Only groups where user is an active member
    const memberships = await this.memberRepo.find({
      where: { userId, status: SharedGroupMemberStatus.ACTIVE },
      select: ['groupId'],
    });
    const groupIds = memberships.map((m) => m.groupId);
    if (groupIds.length === 0) return [];

    return this.groupRepo
      .createQueryBuilder('g')
      .whereInIds(groupIds)
      .andWhere('g.is_active = TRUE')
      .leftJoinAndSelect('g.members', 'members', 'members.status = :status', {
        status: SharedGroupMemberStatus.ACTIVE,
      })
      .leftJoinAndSelect('members.user', 'memberUser')
      .orderBy('g.created_at', 'DESC')
      .getMany();
  }

  async getGroupDetail(userId: string, groupId: string): Promise<SharedGroup> {
    await this.assertActiveMember(userId, groupId);
    const group = await this.groupRepo.findOne({
      where: { id: groupId, isActive: true },
      relations: ['members', 'members.user'],
    });
    if (!group) throw new NotFoundException('Group not found');
    return group;
  }

  async joinGroup(userId: string, dto: JoinGroupDto): Promise<SharedGroup> {
    const invite = await this.inviteRepo.findOne({
      where: { code: dto.code.toUpperCase(), isActive: true },
      relations: ['group'],
    });

    if (!invite || !invite.group) throw new NotFoundException('Invite code not found');
    if (invite.expiresAt && invite.expiresAt < new Date()) {
      throw new GoneException('Invite code has expired');
    }
    if (invite.uses >= invite.maxUses) {
      throw new GoneException('Invite code has reached its maximum uses');
    }

    const group = invite.group;
    if (!group.isActive) throw new GoneException('Group no longer exists');

    // Check if already a member
    const existing = await this.memberRepo.findOne({
      where: { groupId: group.id, userId },
    });
    if (existing) {
      if (existing.status === SharedGroupMemberStatus.ACTIVE) {
        throw new ConflictException('You are already a member of this group');
      }
      // Re-join after leaving
      existing.status = SharedGroupMemberStatus.ACTIVE;
      await this.memberRepo.save(existing);
    } else {
      await this.memberRepo.save(
        this.memberRepo.create({
          groupId: group.id,
          userId,
          status: SharedGroupMemberStatus.ACTIVE,
        }),
      );
    }

    // Increment invite usage counter
    invite.uses += 1;
    await this.inviteRepo.save(invite);

    return group;
  }

  async leaveGroup(userId: string, groupId: string): Promise<void> {
    const membership = await this.memberRepo.findOne({
      where: { groupId, userId, status: SharedGroupMemberStatus.ACTIVE },
    });
    if (!membership) throw new NotFoundException('Membership not found');

    // Owner cannot leave; must transfer ownership or delete the group first
    const group = await this.groupRepo.findOneBy({ id: groupId });
    if (group?.ownerId === userId) {
      throw new BadRequestException('Owner cannot leave the group. Delete it instead.');
    }

    membership.status = SharedGroupMemberStatus.LEFT;
    await this.memberRepo.save(membership);
  }

  async removeMember(ownerId: string, groupId: string, targetUserId: string): Promise<void> {
    const group = await this.groupRepo.findOneBy({ id: groupId });
    if (!group || group.ownerId !== ownerId) {
      throw new ForbiddenException('Only the group owner can remove members');
    }
    const membership = await this.memberRepo.findOne({
      where: { groupId, userId: targetUserId, status: SharedGroupMemberStatus.ACTIVE },
    });
    if (!membership) throw new NotFoundException('Member not found');
    membership.status = SharedGroupMemberStatus.REMOVED;
    await this.memberRepo.save(membership);
  }

  async deleteGroup(userId: string, groupId: string): Promise<void> {
    const group = await this.groupRepo.findOneBy({ id: groupId });
    if (!group) throw new NotFoundException('Group not found');
    if (group.ownerId !== userId) {
      throw new ForbiddenException('Only the group owner can delete the group');
    }
    group.isActive = false;
    await this.groupRepo.save(group);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  async assertActiveMember(userId: string, groupId: string): Promise<void> {
    const m = await this.memberRepo.findOne({
      where: { userId, groupId, status: SharedGroupMemberStatus.ACTIVE },
    });
    if (!m) throw new ForbiddenException('You are not an active member of this group');
  }

  private generateCode(): string {
    return randomBytes(4).toString('hex').toUpperCase();
  }
}
