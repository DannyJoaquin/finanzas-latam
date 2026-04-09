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
import { IncomesService } from './incomes.service';
import { CreateIncomeDto, CreateIncomeRecordDto, UpdateIncomeDto } from './dto/income.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('incomes')
export class IncomesController {
  constructor(private incomesService: IncomesService) {}

  @Get()
  findAll(@CurrentUser() user: User) {
    return this.incomesService.findAll(user.id);
  }

  @Get('projection')
  getProjection(@CurrentUser() user: User) {
    return this.incomesService.getProjection(user.id);
  }

  @Get(':id')
  findOne(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.incomesService.findOne(user.id, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: User, @Body() dto: CreateIncomeDto) {
    return this.incomesService.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateIncomeDto,
  ) {
    return this.incomesService.update(user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.incomesService.remove(user.id, id);
  }

  @Post(':id/records')
  @HttpCode(HttpStatus.CREATED)
  addRecord(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateIncomeRecordDto,
  ) {
    return this.incomesService.addRecord(user.id, id, dto);
  }

  @Get(':id/records')
  getRecords(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.incomesService.getRecords(user.id, id);
  }
}
