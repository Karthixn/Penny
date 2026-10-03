import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateSettlementDto } from './dto/create-settlement.dto.js';

@Injectable()
export class SettlementsService {
  constructor(private prisma: PrismaService) {}

  async getOptimized(userId: string, groupId: string) {
    await this.assertMember(userId, groupId);

    const expenses = await this.prisma.expense.findMany({
      where: { groupId, deletedAt: null },
      include: { payers: true, splits: true },
    });

    const settled = await this.prisma.settlement.findMany({
      where: { groupId, settledAt: { not: null } },
    });

    const balances: Record<string, number> = {};
    for (const exp of expenses) {
      for (const p of exp.payers) {
        balances[p.userId] = (balances[p.userId] ?? 0) + p.amount;
      }
      for (const s of exp.splits) {
        balances[s.userId] = (balances[s.userId] ?? 0) - s.amount;
      }
    }
    for (const s of settled) {
      balances[s.payerId] = (balances[s.payerId] ?? 0) + s.amount;
      balances[s.payeeId] = (balances[s.payeeId] ?? 0) - s.amount;
    }

    // Greedy net-balance settlement algorithm
    const debtors: { userId: string; amount: number }[] = [];
    const creditors: { userId: string; amount: number }[] = [];

    for (const [uid, bal] of Object.entries(balances)) {
      if (bal < 0) debtors.push({ userId: uid, amount: -bal });
      else if (bal > 0) creditors.push({ userId: uid, amount: bal });
    }

    debtors.sort((a, b) => b.amount - a.amount);
    creditors.sort((a, b) => b.amount - a.amount);

    const transactions: { from: string; to: string; amount: number }[] = [];
    let di = 0;
    let ci = 0;

    while (di < debtors.length && ci < creditors.length) {
      const transfer = Math.min(debtors[di].amount, creditors[ci].amount);
      if (transfer > 0) {
        transactions.push({
          from: debtors[di].userId,
          to: creditors[ci].userId,
          amount: transfer,
        });
      }
      debtors[di].amount -= transfer;
      creditors[ci].amount -= transfer;
      if (debtors[di].amount === 0) di++;
      if (creditors[ci].amount === 0) ci++;
    }

    const members = await this.prisma.groupMember.findMany({
      where: { groupId, leftAt: null },
      include: { user: { select: { id: true, displayName: true, email: true, upiId: true } } },
    });
    const userMap = Object.fromEntries(members.map((m) => [m.userId, m.user]));

    return transactions.map((t) => ({
      from: userMap[t.from] ?? { id: t.from },
      to: userMap[t.to] ?? { id: t.to },
      amount: t.amount,
    }));
  }

  async create(userId: string, dto: CreateSettlementDto) {
    await this.assertMember(userId, dto.groupId);

    const payerId = dto.payerId ?? userId;
    await this.assertMember(payerId, dto.groupId);
    await this.assertMember(dto.payeeId, dto.groupId);

    return this.prisma.settlement.create({
      data: {
        groupId: dto.groupId,
        payerId: payerId,
        payeeId: dto.payeeId,
        amount: dto.amount,
        note: dto.note ?? null,
        settledAt: new Date(),
      },
      include: {
        payer: { select: { id: true, displayName: true, email: true } },
        payee: { select: { id: true, displayName: true, email: true } },
      },
    });
  }

  async remove(userId: string, id: string) {
    const settlement = await this.prisma.settlement.findUnique({ where: { id } });
    if (!settlement) throw new NotFoundException('Settlement not found');
    await this.assertMember(userId, settlement.groupId);

    return this.prisma.settlement.delete({
      where: { id },
    });
  }

  async dispute(userId: string, id: string, dto: { isDisputed: boolean; disputeReason?: string }) {
    const settlement = await this.prisma.settlement.findUnique({ where: { id } });
    if (!settlement) throw new NotFoundException('Settlement not found');
    await this.assertMember(userId, settlement.groupId);

    return this.prisma.settlement.update({
      where: { id },
      data: {
        isDisputed: dto.isDisputed,
        disputeReason: dto.disputeReason ?? null,
      },
      include: {
        payer: { select: { id: true, displayName: true, email: true } },
        payee: { select: { id: true, displayName: true, email: true } },
      },
    });
  }

  async markSettled(userId: string, id: string) {
    const settlement = await this.prisma.settlement.findUnique({ where: { id } });
    if (!settlement) throw new NotFoundException();
    if (settlement.payeeId !== userId) throw new ForbiddenException('Only payee can confirm');

    return this.prisma.settlement.update({
      where: { id },
      data: { settledAt: new Date() },
      include: {
        payer: { select: { id: true, displayName: true, email: true } },
        payee: { select: { id: true, displayName: true, email: true } },
      },
    });
  }

  async listForGroup(userId: string, groupId: string) {
    await this.assertMember(userId, groupId);

    return this.prisma.settlement.findMany({
      where: { groupId },
      include: {
        payer: { select: { id: true, displayName: true, email: true } },
        payee: { select: { id: true, displayName: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  generateUpiLink(payeeVpa: string, amount: number, note: string) {
    const amountRupees = (amount / 100).toFixed(2);
    return `upi://pay?pa=${encodeURIComponent(payeeVpa)}&am=${amountRupees}&tn=${encodeURIComponent(note)}`;
  }

  private async assertMember(userId: string, groupId: string) {
    const member = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId } },
    });
    if (!member || member.leftAt) throw new ForbiddenException('Not a group member');
  }
}
