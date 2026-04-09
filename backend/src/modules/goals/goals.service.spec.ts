import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { GoalsService, CreateGoalDto, ContributeGoalDto } from './goals.service';
import { Goal, GoalStatus } from './goal.entity';
import { GoalContribution, ContributionSource } from './goal-contribution.entity';

const mockGoalRepo = () => ({
  find: jest.fn(),
  findOne: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
  update: jest.fn(),
});

const mockContribRepo = () => ({
  find: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
});

describe('GoalsService', () => {
  let service: GoalsService;
  let goalRepo: ReturnType<typeof mockGoalRepo>;
  let contribRepo: ReturnType<typeof mockContribRepo>;

  const userId = 'user-1';
  const goalId = 'goal-1';

  const mockGoal = (): Goal =>
    ({
      id: goalId,
      userId,
      name: 'Viaje a Colombia',
      targetAmount: 5000,
      currentAmount: 0,
      status: GoalStatus.ACTIVE,
      priority: 1,
      contributions: [],
    } as unknown as Goal);

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        GoalsService,
        { provide: getRepositoryToken(Goal), useFactory: mockGoalRepo },
        { provide: getRepositoryToken(GoalContribution), useFactory: mockContribRepo },
      ],
    }).compile();

    service = module.get<GoalsService>(GoalsService);
    goalRepo = module.get(getRepositoryToken(Goal));
    contribRepo = module.get(getRepositoryToken(GoalContribution));
  });

  // ──────────────────────────────────────────────────────────────
  // findAll
  // ──────────────────────────────────────────────────────────────
  describe('findAll', () => {
    it('returns only ACTIVE goals ordered by priority', async () => {
      const goals = [mockGoal()];
      goalRepo.find.mockResolvedValue(goals);

      const result = await service.findAll(userId);

      expect(goalRepo.find).toHaveBeenCalledWith({
        where: { userId, status: GoalStatus.ACTIVE },
        order: { priority: 'ASC', createdAt: 'DESC' },
      });
      expect(result).toEqual(goals);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // findOne
  // ──────────────────────────────────────────────────────────────
  describe('findOne', () => {
    it('returns goal with contributions relation', async () => {
      const goal = mockGoal();
      goalRepo.findOne.mockResolvedValue(goal);

      const result = await service.findOne(userId, goalId);

      expect(goalRepo.findOne).toHaveBeenCalledWith({
        where: { id: goalId, userId },
        relations: ['contributions'],
      });
      expect(result).toEqual(goal);
    });

    it('throws NotFoundException when goal not found', async () => {
      goalRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(userId, 'nonexistent')).rejects.toThrow(NotFoundException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // create
  // ──────────────────────────────────────────────────────────────
  describe('create', () => {
    it('creates goal with correct userId', async () => {
      const dto: CreateGoalDto = { name: 'Vacaciones', targetAmount: 3000 };
      const created = { ...mockGoal(), name: 'Vacaciones', targetAmount: 3000 };
      goalRepo.create.mockReturnValue(created);
      goalRepo.save.mockResolvedValue(created);

      const result = await service.create(userId, dto);

      expect(goalRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ userId, name: 'Vacaciones', targetAmount: 3000 }),
      );
      expect(result).toEqual(created);
    });

    it('converts targetDate string to Date object', async () => {
      const dto: CreateGoalDto = {
        name: 'Meta con fecha',
        targetAmount: 1000,
        targetDate: '2026-12-31',
      };
      goalRepo.create.mockReturnValue({});
      goalRepo.save.mockResolvedValue({});

      await service.create(userId, dto);

      expect(goalRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          targetDate: new Date('2026-12-31'),
        }),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // cancel
  // ──────────────────────────────────────────────────────────────
  describe('cancel', () => {
    it('sets goal status to CANCELLED', async () => {
      const goal = mockGoal();
      goalRepo.findOne.mockResolvedValue(goal);
      goalRepo.save.mockResolvedValue({ ...goal, status: GoalStatus.CANCELLED });

      await service.cancel(userId, goalId);

      expect(goal.status).toBe(GoalStatus.CANCELLED);
      expect(goalRepo.save).toHaveBeenCalledWith(expect.objectContaining({ status: GoalStatus.CANCELLED }));
    });

    it('throws NotFoundException when goal not found', async () => {
      goalRepo.findOne.mockResolvedValue(null);
      await expect(service.cancel(userId, 'bad-id')).rejects.toThrow(NotFoundException);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // contribute
  // ──────────────────────────────────────────────────────────────
  describe('contribute', () => {
    it('adds contribution amount to goal currentAmount', async () => {
      const goal = mockGoal();
      goal.currentAmount = 1000;
      goalRepo.findOne.mockResolvedValue(goal);
      const contribution = { id: 'contrib-1', amount: 500 };
      contribRepo.create.mockReturnValue(contribution);
      contribRepo.save.mockResolvedValue(contribution);
      goalRepo.update.mockResolvedValue({});

      const dto: ContributeGoalDto = { amount: 500 };
      const result = await service.contribute(userId, goalId, dto);

      expect(contribRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          amount: 500,
          source: ContributionSource.MANUAL,
          goalId,
          userId,
        }),
      );
      expect(goalRepo.update).toHaveBeenCalledWith(
        { id: goalId },
        expect.objectContaining({ currentAmount: 1500 }),
      );
      expect(result).toEqual(contribution);
    });

    it('caps currentAmount at targetAmount and marks COMPLETED', async () => {
      const goal = mockGoal();
      goal.currentAmount = 4800;
      goal.targetAmount = 5000;
      goalRepo.findOne.mockResolvedValue(goal);
      contribRepo.create.mockReturnValue({ amount: 500 });
      contribRepo.save.mockResolvedValue({ amount: 500 });
      goalRepo.update.mockResolvedValue({});

      await service.contribute(userId, goalId, { amount: 500 });

      // 4800 + 500 = 5300, capped to 5000, which equals targetAmount → COMPLETED
      expect(goalRepo.update).toHaveBeenCalledWith(
        { id: goalId },
        expect.objectContaining({
          currentAmount: 5000,
          status: GoalStatus.COMPLETED,
        }),
      );
    });

    it('does NOT mark COMPLETED when goal is not yet reached', async () => {
      const goal = mockGoal();
      goal.currentAmount = 100;
      goal.targetAmount = 5000;
      goalRepo.findOne.mockResolvedValue(goal);
      contribRepo.create.mockReturnValue({ amount: 200 });
      contribRepo.save.mockResolvedValue({ amount: 200 });
      goalRepo.update.mockResolvedValue({});

      await service.contribute(userId, goalId, { amount: 200 });

      expect(goalRepo.update).toHaveBeenCalledWith(
        { id: goalId },
        expect.not.objectContaining({ status: GoalStatus.COMPLETED }),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // getContributions
  // ──────────────────────────────────────────────────────────────
  describe('getContributions', () => {
    it('returns contributions ordered by date DESC', async () => {
      const contribs = [{ id: 'c1', amount: 100 }];
      contribRepo.find.mockResolvedValue(contribs);

      const result = await service.getContributions(userId, goalId);

      expect(contribRepo.find).toHaveBeenCalledWith({
        where: { goalId, userId },
        order: { date: 'DESC' },
      });
      expect(result).toEqual(contribs);
    });
  });
});
