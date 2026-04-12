import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { RulesService, CreateRuleDto } from './rules.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('rules')
export class RulesController {
  constructor(private rulesService: RulesService) {}

  @Get()
  findAll(@CurrentUser() user: User) {
    return this.rulesService.findAll(user.id);
  }

  @Get(':id')
  findOne(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.rulesService.findOne(user.id, id);
  }

  @Post()
  create(@CurrentUser() user: User, @Body() dto: CreateRuleDto) {
    return this.rulesService.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: Partial<CreateRuleDto>,
  ) {
    return this.rulesService.update(user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.rulesService.remove(user.id, id);
  }
}
