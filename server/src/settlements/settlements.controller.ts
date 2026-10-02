import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { SettlementsService } from './settlements.service.js';
import { CreateSettlementDto } from './dto/create-settlement.dto.js';

@Controller('settlements')
@UseGuards(JwtAuthGuard)
export class SettlementsController {
  constructor(private settlements: SettlementsService) {}

  @Get('optimize')
  getOptimized(@Req() req: any, @Query('groupId') groupId: string) {
    return this.settlements.getOptimized(req.user.userId, groupId);
  }

  @Get()
  listForGroup(@Req() req: any, @Query('groupId') groupId: string) {
    return this.settlements.listForGroup(req.user.userId, groupId);
  }

  @Post()
  create(@Req() req: any, @Body() dto: CreateSettlementDto) {
    return this.settlements.create(req.user.userId, dto);
  }

  @Patch(':id/settle')
  markSettled(@Req() req: any, @Param('id', ParseUUIDPipe) id: string) {
    return this.settlements.markSettled(req.user.userId, id);
  }

  @Get('upi-link')
  getUpiLink(
    @Query('vpa') vpa: string,
    @Query('amount') amount: string,
    @Query('note') note: string,
  ) {
    return { upiLink: this.settlements.generateUpiLink(vpa, parseInt(amount, 10), note || 'Penny settle') };
  }
}
