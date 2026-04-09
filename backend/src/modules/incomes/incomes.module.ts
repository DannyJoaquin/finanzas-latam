import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Income } from './income.entity';
import { IncomeRecord } from './income-record.entity';
import { IncomesController } from './incomes.controller';
import { IncomesService } from './incomes.service';

@Module({
  imports: [TypeOrmModule.forFeature([Income, IncomeRecord])],
  controllers: [IncomesController],
  providers: [IncomesService],
  exports: [IncomesService],
})
export class IncomesModule {}
