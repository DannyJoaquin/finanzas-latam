import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { InsightsService } from './insights.service';
import { Insight } from './insight.entity';

const mockInsightRepo = () => ({
  find: jest.fn(),
  findOne: jest.fn(),
  save: jest.fn(),
});

describe('InsightsService', () => {
  let service: InsightsService;
  let repo: ReturnType<typeof mockInsightRepo>;

  const userId = 'user-1';
  const insightId = 'insight-1';

  const mockInsight = (): Insight =>
    ({
      id: insightId,
      userId,
      isRead: false,
      isDismissed: false,
      type: 'ANOMALY',
      priority: 'HIGH',
      title: 'Gasto inusual en Restaurantes',
      body: 'Gastaste 2.5x más que la semana pasada.',
      generatedAt: new Date(),
    } as unknown as Insight);

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InsightsService,
        { provide: getRepositoryToken(Insight), useFactory: mockInsightRepo },
      ],
    }).compile();

    service = module.get<InsightsService>(InsightsService);
    repo = module.get(getRepositoryToken(Insight));
  });

  // ──────────────────────────────────────────────────────────────
  // findActive
  // ──────────────────────────────────────────────────────────────
  describe('findActive', () => {
    it('returns only non-dismissed insights, ordered by generatedAt DESC, limit 20', async () => {
      const insights = [mockInsight()];
      repo.find.mockResolvedValue(insights);

      const result = await service.findActive(userId);

      expect(repo.find).toHaveBeenCalledWith({
        where: { userId, isDismissed: false },
        order: { generatedAt: 'DESC' },
        take: 20,
      });
      expect(result).toEqual(insights);
    });

    it('returns empty array when no active insights', async () => {
      repo.find.mockResolvedValue([]);
      const result = await service.findActive(userId);
      expect(result).toEqual([]);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // markRead
  // ──────────────────────────────────────────────────────────────
  describe('markRead', () => {
    it('sets isRead=true on the insight', async () => {
      const insight = mockInsight();
      repo.findOne.mockResolvedValue(insight);
      repo.save.mockResolvedValue({ ...insight, isRead: true });

      await service.markRead(userId, insightId);

      expect(insight.isRead).toBe(true);
      expect(repo.save).toHaveBeenCalledWith(expect.objectContaining({ isRead: true }));
    });

    it('throws NotFoundException when insight not found', async () => {
      repo.findOne.mockResolvedValue(null);
      await expect(service.markRead(userId, 'bad-id')).rejects.toThrow(NotFoundException);
    });

    it('queries by both id and userId (security check)', async () => {
      repo.findOne.mockResolvedValue(null);
      await service.markRead(userId, insightId).catch(() => {});
      expect(repo.findOne).toHaveBeenCalledWith({
        where: { id: insightId, userId },
      });
    });
  });

  // ──────────────────────────────────────────────────────────────
  // dismiss
  // ──────────────────────────────────────────────────────────────
  describe('dismiss', () => {
    it('sets isDismissed=true on the insight', async () => {
      const insight = mockInsight();
      repo.findOne.mockResolvedValue(insight);
      repo.save.mockResolvedValue({ ...insight, isDismissed: true });

      await service.dismiss(userId, insightId);

      expect(insight.isDismissed).toBe(true);
      expect(repo.save).toHaveBeenCalledWith(expect.objectContaining({ isDismissed: true }));
    });

    it('throws NotFoundException when insight not found', async () => {
      repo.findOne.mockResolvedValue(null);
      await expect(service.dismiss(userId, 'bad-id')).rejects.toThrow(NotFoundException);
    });

    it('queries by both id and userId (security check)', async () => {
      repo.findOne.mockResolvedValue(null);
      await service.dismiss(userId, insightId).catch(() => {});
      expect(repo.findOne).toHaveBeenCalledWith({
        where: { id: insightId, userId },
      });
    });
  });
});
