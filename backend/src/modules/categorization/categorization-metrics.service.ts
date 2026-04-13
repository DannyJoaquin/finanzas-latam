import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CategorizationAuditLog } from './categorization-audit-log.entity';

export interface CategoryAccuracyStat {
  categoryId: string | null;
  categoryName: string | null;
  total: number;
  corrected: number;
  errorRate: number;
}

export interface CategorizationStats {
  totalExpenses: number;
  autoCategorized: number;
  autoCategorizedPct: number;
  corrected: number;
  correctedPct: number;
  topAccurate: CategoryAccuracyStat[];
  topInaccurate: CategoryAccuracyStat[];
}

@Injectable()
export class CategorizationMetricsService {
  constructor(
    @InjectRepository(CategorizationAuditLog)
    private auditLogRepo: Repository<CategorizationAuditLog>,
  ) {}

  async getStats(
    userId: string,
    opts: { startDate?: Date; endDate?: Date } = {},
  ): Promise<CategorizationStats> {
    const qb = this.auditLogRepo
      .createQueryBuilder('log')
      .where('log.userId = :userId', { userId })
      .andWhere('log.expenseId IS NOT NULL'); // only persisted expenses

    if (opts.startDate) {
      qb.andWhere('log.createdAt >= :start', { start: opts.startDate });
    }
    if (opts.endDate) {
      qb.andWhere('log.createdAt <= :end', { end: opts.endDate });
    }

    const logs = await qb
      .leftJoinAndSelect('log.suggestedCategory', 'cat')
      .getMany();

    const total = logs.length;
    const autoCategorized = logs.filter((l) => l.wasAutoAssigned).length;
    const corrected = logs.filter((l) => l.wasCorrected).length;

    // Group by suggested category
    const byCat = new Map<
      string,
      { name: string | null; total: number; corrected: number }
    >();

    for (const log of logs) {
      if (!log.wasAutoAssigned) continue;
      const key = log.suggestedCategoryId ?? '__uncategorized__';
      const name = log.suggestedCategory?.name ?? null;
      const existing = byCat.get(key) ?? { name, total: 0, corrected: 0 };
      existing.total += 1;
      if (log.wasCorrected) existing.corrected += 1;
      byCat.set(key, existing);
    }

    const statsArray: CategoryAccuracyStat[] = [...byCat.entries()].map(
      ([id, stat]) => ({
        categoryId: id === '__uncategorized__' ? null : id,
        categoryName: stat.name,
        total: stat.total,
        corrected: stat.corrected,
        errorRate:
          stat.total > 0
            ? Math.round((stat.corrected / stat.total) * 1000) / 10
            : 0,
      }),
    );

    const topAccurate = [...statsArray]
      .filter((s) => s.total >= 3)
      .sort((a, b) => a.errorRate - b.errorRate)
      .slice(0, 5);

    const topInaccurate = [...statsArray]
      .filter((s) => s.total >= 3)
      .sort((a, b) => b.errorRate - a.errorRate)
      .slice(0, 5);

    return {
      totalExpenses: total,
      autoCategorized,
      autoCategorizedPct:
        total > 0 ? Math.round((autoCategorized / total) * 1000) / 10 : 0,
      corrected,
      correctedPct:
        autoCategorized > 0
          ? Math.round((corrected / autoCategorized) * 1000) / 10
          : 0,
      topAccurate,
      topInaccurate,
    };
  }
}
