import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { RemindersService } from './reminders.service.js';
import { RemindersController } from './reminders.controller.js';

@Module({
  imports: [AuthModule],
  controllers: [RemindersController],
  providers: [RemindersService],
  exports: [RemindersService],
})
export class RemindersModule {}
