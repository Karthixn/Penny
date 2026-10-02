import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { SettlementsService } from './settlements.service.js';
import { SettlementsController } from './settlements.controller.js';

@Module({
  imports: [AuthModule],
  controllers: [SettlementsController],
  providers: [SettlementsService],
  exports: [SettlementsService],
})
export class SettlementsModule {}
