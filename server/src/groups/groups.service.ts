import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateGroupDto } from './dto/create-group.dto.js';
import { UpdateGroupDto } from './dto/update-group.dto.js';
import { v4 as uuid } from 'uuid';

const memberSelect = {
  id: true,
  displayName: true,
  email: true,
} as const;

@Injectable()
export class GroupsService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, dto: CreateGroupDto) {
    return this.prisma.group.create({
      data: {
        name: dto.name,
        emoji: dto.emoji,
        createdBy: userId,
        members: {
          create: { userId, role: 'admin' },
        },
      },
      include: {
        members: { include: { user: { select: memberSelect } } },
      },
    });
  }

  async findAll(userId: string) {
    return this.prisma.group.findMany({
      where: {
        members: { some: { userId, leftAt: null } },
        archivedAt: null,
      },
      include: {
        members: {
          where: { leftAt: null },
          include: { user: { select: memberSelect } },
        },
        _count: { select: { expenses: { where: { deletedAt: null } } } },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async findOne(userId: string, id: string) {
    const group = await this.prisma.group.findFirst({
      where: { id, members: { some: { userId, leftAt: null } } },
      include: {
        members: {
          where: { leftAt: null },
          include: { user: { select: memberSelect } },
        },
        creator: { select: memberSelect },
      },
    });
    if (!group) throw new NotFoundException('Group not found');
    return group;
  }

  async update(userId: string, id: string, dto: UpdateGroupDto) {
    await this.assertAdmin(userId, id);
    return this.prisma.group.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name }),
        ...(dto.emoji !== undefined && { emoji: dto.emoji }),
      },
      include: {
        members: {
          where: { leftAt: null },
          include: { user: { select: memberSelect } },
        },
      },
    });
  }

  async addMember(userId: string, groupId: string, memberId: string, role = 'member') {
    await this.assertAdmin(userId, groupId);

    const existing = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId: memberId } },
    });

    if (existing && !existing.leftAt) {
      throw new ConflictException('User is already a member');
    }

    if (existing) {
      return this.prisma.groupMember.update({
        where: { id: existing.id },
        data: { leftAt: null, role },
        include: { user: { select: memberSelect } },
      });
    }

    return this.prisma.groupMember.create({
      data: { groupId, userId: memberId, role },
      include: { user: { select: memberSelect } },
    });
  }

  async removeMember(userId: string, groupId: string, memberId: string) {
    if (userId !== memberId) await this.assertAdmin(userId, groupId);

    const member = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId: memberId } },
    });
    if (!member || member.leftAt) throw new NotFoundException('Member not found');

    return this.prisma.groupMember.update({
      where: { id: member.id },
      data: { leftAt: new Date() },
    });
  }

  async getBalances(userId: string, groupId: string) {
    await this.findOne(userId, groupId);

    const expenses = await this.prisma.expense.findMany({
      where: { groupId, deletedAt: null },
      include: { payers: true, splits: true },
    });

    const settlements = await this.prisma.settlement.findMany({
      where: { groupId, settledAt: { not: null } },
    });

    const balances: Record<string, number> = {};

    for (const exp of expenses) {
      for (const payer of exp.payers) {
        balances[payer.userId] = (balances[payer.userId] ?? 0) + payer.amount;
      }
      for (const split of exp.splits) {
        balances[split.userId] = (balances[split.userId] ?? 0) - split.amount;
      }
    }

    for (const s of settlements) {
      balances[s.payerId] = (balances[s.payerId] ?? 0) + s.amount;
      balances[s.payeeId] = (balances[s.payeeId] ?? 0) - s.amount;
    }

    const members = await this.prisma.groupMember.findMany({
      where: { groupId, leftAt: null },
      include: { user: { select: memberSelect } },
    });

    return members.map((m) => ({
      user: m.user,
      balance: balances[m.userId] ?? 0,
    }));
  }

  async createInvite(userId: string, groupId: string) {
    await this.assertAdmin(userId, groupId);
    const code = uuid().replace(/-/g, '').substring(0, 8).toUpperCase();
    return this.prisma.groupInvitation.create({
      data: {
        groupId,
        invitedBy: userId,
        inviteCode: code,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });
  }

  async joinByInvite(userId: string, inviteCode: string) {
    const invite = await this.prisma.groupInvitation.findUnique({
      where: { inviteCode },
    });
    if (!invite || invite.usedAt || invite.expiresAt < new Date()) {
      throw new NotFoundException('Invalid or expired invite');
    }

    await this.prisma.groupInvitation.update({
      where: { id: invite.id },
      data: { usedAt: new Date() },
    });

    const existing = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId: invite.groupId, userId } },
    });

    if (existing && !existing.leftAt) return this.findOne(userId, invite.groupId);

    if (existing) {
      await this.prisma.groupMember.update({
        where: { id: existing.id },
        data: { leftAt: null },
      });
    } else {
      await this.prisma.groupMember.create({
        data: { groupId: invite.groupId, userId },
      });
    }

    return this.findOne(userId, invite.groupId);
  }

  async archive(userId: string, id: string) {
    await this.assertAdmin(userId, id);
    await this.prisma.group.update({
      where: { id },
      data: { archivedAt: new Date() },
    });
  }

  private async assertAdmin(userId: string, groupId: string) {
    const member = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId } },
    });
    if (!member || member.leftAt || member.role !== 'admin') {
      throw new ForbiddenException('Admin access required');
    }
  }
}
