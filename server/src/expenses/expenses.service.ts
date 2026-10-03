import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateExpenseDto } from './dto/create-expense.dto.js';
import { UpdateExpenseDto } from './dto/update-expense.dto.js';

@Injectable()
export class ExpensesService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, dto: CreateExpenseDto) {
    return this.prisma.$transaction(async (tx) => {
      let resolveUserId = (id: string) => id;
      if (dto.groupId) {
        const groupMembers = await tx.groupMember.findMany({
          where: { groupId: dto.groupId, leftAt: null },
          select: { id: true, userId: true },
        });
        const memberMap = new Map<string, string>();
        for (const gm of groupMembers) {
          memberMap.set(gm.id, gm.userId);
          memberMap.set(gm.userId, gm.userId);
        }
        resolveUserId = (id: string) => memberMap.get(id) ?? id;
      }

      // Consolidate payers by resolved userId
      const rawPayers = dto.payers?.length
        ? dto.payers
        : [{ userId, amount: dto.totalAmount }];
      const payersMap = new Map<string, number>();
      for (const p of rawPayers) {
        const uid = resolveUserId(p.userId);
        payersMap.set(uid, (payersMap.get(uid) ?? 0) + p.amount);
      }

      // Consolidate splits by resolved userId
      const rawSplits = dto.splits?.length
        ? dto.splits
        : [{ userId, amount: dto.totalAmount, splitMethod: 'equal' }];
      const splitsMap = new Map<string, { amount: number; splitMethod: string }>();
      for (const s of rawSplits) {
        const uid = resolveUserId(s.userId);
        const existing = splitsMap.get(uid);
        splitsMap.set(uid, {
          amount: (existing?.amount ?? 0) + s.amount,
          splitMethod: s.splitMethod ?? 'equal',
        });
      }

      const expense = await tx.expense.create({
        data: {
          description: dto.description,
          totalAmount: dto.totalAmount,
          category: dto.category ?? 'other',
          type: dto.type ?? 'expense',
          paymentMethod: dto.paymentMethod ?? null,
          tags: dto.tags ?? [],
          date: dto.date ? new Date(dto.date) : new Date(),
          createdBy: userId,
          groupId: dto.groupId ?? null,
          clientId: dto.clientId ?? null,
          payers: {
            create: Array.from(payersMap.entries()).map(([uid, amount]) => ({
              userId: uid,
              amount,
            })),
          },
          splits: {
            create: Array.from(splitsMap.entries()).map(([uid, data]) => ({
              userId: uid,
              amount: data.amount,
              splitMethod: data.splitMethod,
            })),
          },
        },
        include: {
          payers: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          splits: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          items: { include: { assignees: true } },
          creator: { select: { id: true, displayName: true, email: true } },
        },
      });

      if (dto.items?.length) {
        for (const item of dto.items) {
          await tx.expenseItem.create({
            data: {
              expenseId: expense.id,
              name: item.name,
              amount: item.amount,
              assignees: {
                create: item.assigneeIds.map((uid) => ({ userId: uid })),
              },
            },
          });
        }
      }

      return tx.expense.findFirstOrThrow({
        where: { id: expense.id },
        include: {
          payers: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          splits: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          items: {
            include: {
              assignees: {
                include: { user: { select: { id: true, displayName: true, email: true } } },
              },
            },
          },
          creator: { select: { id: true, displayName: true, email: true } },
        },
      });
    });
  }

  async findAll(userId: string, query: { groupId?: string; page?: number; limit?: number }) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where: any = { deletedAt: null };

    if (query.groupId) {
      where.groupId = query.groupId;
    } else {
      where.OR = [
        { createdBy: userId, groupId: null },
        { payers: { some: { userId } } },
        { splits: { some: { userId } } },
      ];
    }

    const [expenses, total] = await Promise.all([
      this.prisma.expense.findMany({
        where,
        include: {
          payers: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          splits: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          creator: { select: { id: true, displayName: true, email: true } },
        },
        orderBy: { date: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.expense.count({ where }),
    ]);

    return { data: expenses, total, page, limit };
  }

  async findOne(userId: string, id: string) {
    const expense = await this.prisma.expense.findFirst({
      where: { id, deletedAt: null },
      include: {
        payers: { include: { user: { select: { id: true, displayName: true, email: true } } } },
        splits: { include: { user: { select: { id: true, displayName: true, email: true } } } },
        items: {
          include: {
            assignees: {
              include: { user: { select: { id: true, displayName: true, email: true } } },
            },
          },
        },
        creator: { select: { id: true, displayName: true, email: true } },
      },
    });

    if (!expense) throw new NotFoundException('Expense not found');
    return expense;
  }

  async update(userId: string, id: string, dto: UpdateExpenseDto) {
    const expense = await this.prisma.expense.findFirst({
      where: { id, deletedAt: null },
    });
    if (!expense) throw new NotFoundException('Expense not found');
    if (expense.groupId) {
      const isMember = await this.prisma.groupMember.findFirst({
        where: { groupId: expense.groupId, userId, leftAt: null },
      });
      if (!isMember) throw new ForbiddenException();
    } else {
      if (expense.createdBy !== userId) throw new ForbiddenException();
    }

    return this.prisma.$transaction(async (tx) => {
      let resolveUserId = (id: string) => id;
      if (expense.groupId) {
        const groupMembers = await tx.groupMember.findMany({
          where: { groupId: expense.groupId, leftAt: null },
          select: { id: true, userId: true },
        });
        const memberMap = new Map<string, string>();
        for (const gm of groupMembers) {
          memberMap.set(gm.id, gm.userId);
          memberMap.set(gm.userId, gm.userId);
        }
        resolveUserId = (id: string) => memberMap.get(id) ?? id;
      }

      if (dto.payers?.length) {
        const payersMap = new Map<string, number>();
        for (const p of dto.payers) {
          const uid = resolveUserId(p.userId);
          payersMap.set(uid, (payersMap.get(uid) ?? 0) + p.amount);
        }
        await tx.expensePayer.deleteMany({ where: { expenseId: id } });
        await tx.expensePayer.createMany({
          data: Array.from(payersMap.entries()).map(([uid, amount]) => ({
            expenseId: id,
            userId: uid,
            amount,
          })),
        });
      }

      if (dto.splits?.length) {
        const splitsMap = new Map<string, { amount: number; splitMethod: string }>();
        for (const s of dto.splits) {
          const uid = resolveUserId(s.userId);
          const existing = splitsMap.get(uid);
          splitsMap.set(uid, {
            amount: (existing?.amount ?? 0) + s.amount,
            splitMethod: s.splitMethod ?? 'equal',
          });
        }
        await tx.expenseSplit.deleteMany({ where: { expenseId: id } });
        await tx.expenseSplit.createMany({
          data: Array.from(splitsMap.entries()).map(([uid, data]) => ({
            expenseId: id,
            userId: uid,
            amount: data.amount,
            splitMethod: data.splitMethod,
          })),
        });
      }

      return tx.expense.update({
        where: { id },
        data: {
          ...(dto.description && { description: dto.description }),
          ...(dto.totalAmount && { totalAmount: dto.totalAmount }),
          ...(dto.category && { category: dto.category }),
          ...(dto.date && { date: new Date(dto.date) }),
          ...(dto.type && { type: dto.type }),
          ...(dto.paymentMethod !== undefined && { paymentMethod: dto.paymentMethod }),
          ...(dto.tags !== undefined && { tags: dto.tags }),
          ...(dto.isDisputed !== undefined && { isDisputed: dto.isDisputed }),
          ...(dto.disputeReason !== undefined && { disputeReason: dto.disputeReason }),
        },
        include: {
          payers: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          splits: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          creator: { select: { id: true, displayName: true, email: true } },
        },
      });
    });
  }

  async dispute(userId: string, id: string, dto: { isDisputed: boolean; disputeReason?: string }) {
    const expense = await this.prisma.expense.findFirst({
      where: { id, deletedAt: null },
    });
    if (!expense) throw new NotFoundException('Expense not found');
    if (expense.groupId) {
      const isMember = await this.prisma.groupMember.findFirst({
        where: { groupId: expense.groupId, userId, leftAt: null },
      });
      if (!isMember) throw new ForbiddenException();
    } else {
      if (expense.createdBy !== userId) throw new ForbiddenException();
    }

    return this.prisma.expense.update({
      where: { id },
      data: {
        isDisputed: dto.isDisputed,
        disputeReason: dto.disputeReason ?? null,
      },
      include: {
        payers: { include: { user: { select: { id: true, displayName: true, email: true } } } },
        splits: { include: { user: { select: { id: true, displayName: true, email: true } } } },
        creator: { select: { id: true, displayName: true, email: true } },
      },
    });
  }

  async remove(userId: string, id: string) {
    const expense = await this.prisma.expense.findFirst({
      where: { id, deletedAt: null },
    });
    if (!expense) throw new NotFoundException('Expense not found');
    if (expense.groupId) {
      const isMember = await this.prisma.groupMember.findFirst({
        where: { groupId: expense.groupId, userId, leftAt: null },
      });
      if (!isMember) throw new ForbiddenException();
    } else {
      if (expense.createdBy !== userId) throw new ForbiddenException();
    }

    await this.prisma.expense.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  async getMonthlyStats(userId: string, year: number, month: number) {
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 1);

    const expenses = await this.prisma.expense.findMany({
      where: {
        deletedAt: null,
        date: { gte: startDate, lt: endDate },
        OR: [
          { createdBy: userId, groupId: null },
          { splits: { some: { userId } } },
        ],
      },
      include: { splits: true },
    });

    let totalSpent = 0;
    let totalIncome = 0;
    const byCategory: Record<string, number> = {};
    const byPaymentMethod: Record<string, number> = {};
    const byTags: Record<string, number> = {};

    for (const exp of expenses) {
      let userAmount: number;
      if (exp.groupId) {
        const split = exp.splits.find((s) => s.userId === userId);
        userAmount = split?.amount ?? 0;
      } else {
        userAmount = exp.totalAmount;
      }

      if (exp.type === 'income') {
        totalIncome += userAmount;
      } else {
        totalSpent += userAmount;
        byCategory[exp.category] = (byCategory[exp.category] ?? 0) + userAmount;
        if (exp.paymentMethod) {
          byPaymentMethod[exp.paymentMethod] = (byPaymentMethod[exp.paymentMethod] ?? 0) + userAmount;
        }
        if (exp.tags?.length) {
          for (const t of exp.tags) {
            byTags[t] = (byTags[t] ?? 0) + userAmount;
          }
        }
      }
    }

    return {
      totalSpent,
      totalIncome,
      netSavings: totalIncome - totalSpent,
      byCategory,
      byPaymentMethod,
      byTags,
      expenseCount: expenses.length,
    };
  }
}
