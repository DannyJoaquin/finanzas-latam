import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  IsDateString, IsInt, IsNumber, IsOptional, IsPositive, IsString, Length, Max, Min,
} from 'class-validator';
import { Goal, GoalStatus } from './goal.entity';
import { GoalContribution, ContributionSource } from './goal-contribution.entity';

export class CreateGoalDto {
  @IsString()
  @Length(1, 150)
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsNumber()
  @IsPositive()
  targetAmount: number;

  @IsOptional()
  @IsDateString()
  targetDate?: string;

  @IsOptional()
  @IsString()
  icon?: string;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  autoSavePct?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  autoSaveFixed?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  priority?: number;
}

export class ContributeGoalDto {
  @IsNumber()
  @IsPositive()
  amount: number;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsDateString()
  date?: string;
}

@Injectable()
export class GoalsService {
  constructor(
    @InjectRepository(Goal)
    private goalRepo: Repository<Goal>,
    @InjectRepository(GoalContribution)
    private contributionRepo: Repository<GoalContribution>,
  ) {}

  findAll(userId: string): Promise<Goal[]> {
    return this.goalRepo.find({
      where: { userId, status: GoalStatus.ACTIVE },
      order: { priority: 'ASC', createdAt: 'DESC' },
    });
  }

  async findOne(userId: string, id: string): Promise<Goal> {
    const goal = await this.goalRepo.findOne({
      where: { id, userId },
      relations: ['contributions'],
    });
    if (!goal) throw new NotFoundException('Goal not found');
    return goal;
  }

  async create(userId: string, dto: CreateGoalDto): Promise<Goal> {
    const goal = this.goalRepo.create({
      ...dto,
      userId,
      targetDate: dto.targetDate ? new Date(dto.targetDate) : undefined,
    });
    return this.goalRepo.save(goal);
  }

  async update(userId: string, id: string, dto: Partial<CreateGoalDto>): Promise<Goal> {
    const goal = await this.findOne(userId, id);
    Object.assign(goal, dto);
    return this.goalRepo.save(goal);
  }

  async cancel(userId: string, id: string): Promise<void> {
    const goal = await this.findOne(userId, id);
    goal.status = GoalStatus.CANCELLED;
    await this.goalRepo.save(goal);
  }

  async contribute(userId: string, goalId: string, dto: ContributeGoalDto): Promise<GoalContribution> {
    const goal = await this.findOne(userId, goalId);
    const contribution = this.contributionRepo.create({
      goalId,
      userId,
      amount: dto.amount,
      notes: dto.notes,
      date: dto.date ? new Date(dto.date) : new Date(),
      source: ContributionSource.MANUAL,
    });
    await this.contributionRepo.save(contribution);

    const newAmount = Number(goal.currentAmount) + Number(dto.amount);
    const capped = Math.min(newAmount, Number(goal.targetAmount));
    const updates: { currentAmount: number; status?: GoalStatus } = { currentAmount: capped };
    if (capped >= Number(goal.targetAmount)) {
      updates.status = GoalStatus.COMPLETED;
    }
    await this.goalRepo.update({ id: goalId }, updates);
    return contribution;
  }

  getContributions(userId: string, goalId: string): Promise<GoalContribution[]> {
    return this.contributionRepo.find({
      where: { goalId, userId },
      order: { date: 'DESC' },
    });
  }
}
