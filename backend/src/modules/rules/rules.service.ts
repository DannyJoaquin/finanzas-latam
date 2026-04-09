import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Rule } from './rule.entity';

export class CreateRuleDto {
  name: string;
  triggerType: string;
  conditions: { field: string; op: string; value: unknown }[];
  actions: { type: string; params: Record<string, unknown> }[];
  priority?: number;
}

@Injectable()
export class RulesService {
  constructor(
    @InjectRepository(Rule)
    private ruleRepo: Repository<Rule>,
  ) {}

  findAll(userId: string): Promise<Rule[]> {
    return this.ruleRepo.find({ where: { userId }, order: { priority: 'ASC' } });
  }

  async findOne(userId: string, id: string): Promise<Rule> {
    const rule = await this.ruleRepo.findOne({ where: { id, userId } });
    if (!rule) throw new NotFoundException('Rule not found');
    return rule;
  }

  create(userId: string, dto: CreateRuleDto): Promise<Rule> {
    const rule = this.ruleRepo.create({ ...dto, userId } as Partial<Rule>);
    return this.ruleRepo.save(rule);
  }

  async update(userId: string, id: string, dto: Partial<CreateRuleDto>): Promise<Rule> {
    const rule = await this.findOne(userId, id);
    Object.assign(rule, dto);
    return this.ruleRepo.save(rule);
  }

  async remove(userId: string, id: string): Promise<void> {
    const rule = await this.findOne(userId, id);
    await this.ruleRepo.remove(rule);
  }
}
