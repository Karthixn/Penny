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
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { GroupsService } from './groups.service.js';
import { CreateGroupDto } from './dto/create-group.dto.js';
import { UpdateGroupDto } from './dto/update-group.dto.js';
import { AddMemberDto } from './dto/add-member.dto.js';

@Controller('groups')
@UseGuards(JwtAuthGuard)
export class GroupsController {
  constructor(private groups: GroupsService) {}

  @Post()
  create(@Req() req: any, @Body() dto: CreateGroupDto) {
    return this.groups.create(req.user.userId, dto);
  }

  @Get()
  findAll(@Req() req: any) {
    return this.groups.findAll(req.user.userId);
  }

  @Get(':id')
  findOne(@Req() req: any, @Param('id', ParseUUIDPipe) id: string) {
    return this.groups.findOne(req.user.userId, id);
  }

  @Patch(':id')
  update(
    @Req() req: any,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateGroupDto,
  ) {
    return this.groups.update(req.user.userId, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  archive(@Req() req: any, @Param('id', ParseUUIDPipe) id: string) {
    return this.groups.archive(req.user.userId, id);
  }

  @Get(':id/balances')
  getBalances(@Req() req: any, @Param('id', ParseUUIDPipe) id: string) {
    return this.groups.getBalances(req.user.userId, id);
  }

  @Post(':id/members')
  addMember(
    @Req() req: any,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddMemberDto,
  ) {
    return this.groups.addMember(req.user.userId, id, dto.userId, dto.role);
  }

  @Delete(':id/members/:memberId')
  @HttpCode(HttpStatus.NO_CONTENT)
  removeMember(
    @Req() req: any,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
  ) {
    return this.groups.removeMember(req.user.userId, id, memberId);
  }

  @Post(':id/invite')
  createInvite(@Req() req: any, @Param('id', ParseUUIDPipe) id: string) {
    return this.groups.createInvite(req.user.userId, id);
  }

  @Post('join/:code')
  joinByInvite(@Req() req: any, @Param('code') code: string) {
    return this.groups.joinByInvite(req.user.userId, code);
  }
}
