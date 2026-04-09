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
    return this.insightRepo.find({
      where: { userId, isDismissed: false },
      order: { generatedAt: 'DESC' },
      take: 20,
    });
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
}
