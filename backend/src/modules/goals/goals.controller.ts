import {
  Body, Controller, Delete, Get, HttpCode, HttpStatus,
  Param, ParseUUIDPipe, Patch, Post,
} from '@nestjs/common';
import { GoalsService, ContributeGoalDto, CreateGoalDto } from './goals.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('goals')
export class GoalsController {
  constructor(private goalsService: GoalsService) {}

  @Get()
  findAll(@CurrentUser() user: User) {
    return this.goalsService.findAll(user.id);
  }

  @Get(':id')
  findOne(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.goalsService.findOne(user.id, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: User, @Body() dto: CreateGoalDto) {
    return this.goalsService.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: Partial<CreateGoalDto>,
  ) {
    return this.goalsService.update(user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  cancel(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.goalsService.cancel(user.id, id);
  }

  @Post(':id/contribute')
  @HttpCode(HttpStatus.CREATED)
  contribute(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ContributeGoalDto,
  ) {
    return this.goalsService.contribute(user.id, id, dto);
  }

  @Get(':id/contributions')
  getContributions(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.goalsService.getContributions(user.id, id);
  }
}
