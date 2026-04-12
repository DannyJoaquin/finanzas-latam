import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Insight } from './insight.entity';

@Injectable()
export class InsightsService {
  constructor(
    @InjectRepository(Insight)
    private insightRepo: Repository<Insight>,
  ) {}

  findActive(userId: string): Promise<Insight[]> {
    // Exclude dismissed insights AND insights whose expiry has passed
    return this.insightRepo
      .createQueryBuilder('i')
      .where('i.userId = :userId', { userId })
      .andWhere('i.isDismissed = false')
      .andWhere('(i.expiresAt IS NULL OR i.expiresAt > NOW())')
      .orderBy('i.generatedAt', 'DESC')
      .take(20)
      .getMany();
  }

  /** All achievement + streak insights regardless of dismissal — for the trophy-case screen. */
  findAchievements(userId: string): Promise<Insight[]> {
    return this.insightRepo
      .createQueryBuilder('i')
      .where('i.userId = :userId', { userId })
      .andWhere('i.type IN (:...types)', { types: ['achievement', 'streak'] })
      .orderBy('i.generatedAt', 'DESC')
      .getMany();
  }

  async markRead(userId: string, id: string): Promise<void> {
    const insight = await this.insightRepo.findOne({ where: { id, userId } });
    if (!insight) throw new NotFoundException('Insight not found');
    insight.isRead = true;
    await this.insightRepo.save(insight);
  }

  async dismiss(userId: string, id: string): Promise<void> {
    const insight = await this.insightRepo.findOne({ where: { id, userId } });
    if (!insight) throw new NotFoundException('Insight not found');
    insight.isDismissed = true;
    await this.insightRepo.save(insight);
  }

  async dismissAll(userId: string): Promise<void> {
    await this.insightRepo.update({ userId, isDismissed: false }, { isDismissed: true });
  }
}
