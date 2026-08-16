import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SharedSettlement, SharedSettlementPaymentMethod } from './entities/shared-settlement.entity';
import { CreateSettlementDto, UpdateSettlementDto } from './shared-groups.dto';
import { SharedGroupsService } from './shared-groups.service';
import { CashService } from '../cash/cash.service';
import { PushNotificationService } from '../../common/services/push-notification.service';
import { User } from '../users/user.entity';

@Injectable()
export class SettlementsService {
  constructor(
    @InjectRepository(SharedSettlement)
    private settlementRepo: Repository<SharedSettlement>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
    private groupsService: SharedGroupsService,
    private cashService: CashService,
    private pushService: PushNotificationService,
  ) {}

  async createSettlement(
    payerId: string,
    groupId: string,
    dto: CreateSettlementDto,
  ): Promise<SharedSettlement> {
    // Both parties must be active members
    await this.groupsService.assertActiveMember(payerId, groupId);
    await this.groupsService.assertActiveMember(dto.receiverId, groupId);

    const settlement = this.settlementRepo.create({
      groupId,
      payerId,
      receiverId: dto.receiverId,
      amount: dto.amount,
      paymentMethod: dto.paymentMethod ?? SharedSettlementPaymentMethod.CASH,
      note: dto.note,
      date: new Date(dto.date),
    });
    const saved = await this.settlementRepo.save(settlement);

    // Cash impact for the payer (money going out)
    const isCash =
      (dto.paymentMethod ?? SharedSettlementPaymentMethod.CASH) ===
      SharedSettlementPaymentMethod.CASH;

    if (isCash && dto.payerCashAccountId) {
      try {
        await this.cashService.withdraw(payerId, dto.payerCashAccountId, {
          amount: dto.amount,
          description: `[Liquidación] Pago a grupo`,
          date: dto.date,
        });
      } catch {
        // Non-fatal: proceed even if cash balance is insufficient
      }
    }

    // Notify the receiver
    const receiver = await this.userRepo.findOne({
      where: { id: dto.receiverId },
      select: ['id', 'fullName', 'fcmToken'],
    });
    if (receiver?.fcmToken) {
      await this.pushService.send({
        userId: receiver.id,
        fcmToken: receiver.fcmToken,
        title: 'Recibiste un pago',
        body: `L ${Number(dto.amount).toFixed(2)} — liquidación en grupo compartido`,
        data: { type: 'shared_settlement', groupId, settlementId: saved.id },
      }).catch(() => {/* Non-fatal */});
    }

    return saved;
  }

  async getGroupSettlements(userId: string, groupId: string): Promise<SharedSettlement[]> {
    await this.groupsService.assertActiveMember(userId, groupId);
    return this.settlementRepo.find({
      where: { groupId },
      relations: ['payer', 'receiver'],
      order: { date: 'DESC', createdAt: 'DESC' },
    });
  }

  async updateSettlement(
    userId: string,
    groupId: string,
    settlementId: string,
    dto: UpdateSettlementDto,
  ): Promise<SharedSettlement> {
    const settlement = await this.getEditableSettlement(userId, groupId, settlementId);
    Object.assign(settlement, {
      ...dto,
      ...(dto.date ? { date: new Date(dto.date) } : {}),
    });
    return this.settlementRepo.save(settlement);
  }

  async removeSettlement(userId: string, groupId: string, settlementId: string): Promise<void> {
    const settlement = await this.getEditableSettlement(userId, groupId, settlementId);
    await this.settlementRepo.remove(settlement);
  }

  private async getEditableSettlement(
    userId: string,
    groupId: string,
    settlementId: string,
  ): Promise<SharedSettlement> {
    const group = await this.groupsService.getGroupDetail(userId, groupId);
    const settlement = await this.settlementRepo.findOne({
      where: { id: settlementId, groupId },
      relations: ['payer', 'receiver'],
    });
    if (!settlement) throw new NotFoundException('Settlement not found');
    if (settlement.payerId !== userId && group.ownerId !== userId) {
      throw new ForbiddenException('Only the payer or group owner can edit this settlement');
    }
    return settlement;
  }
}
