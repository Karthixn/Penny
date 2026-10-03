import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateExpenseDto } from './dto/create-expense.dto.js';
import { UpdateExpenseDto } from './dto/update-expense.dto.js';

@Injectable()
export class ExpensesService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, dto: CreateExpenseDto) {
    return this.prisma.$transaction(async (tx) => {
      const expense = await tx.expense.create({
        data: {
          description: dto.description,
          totalAmount: dto.totalAmount,
          category: dto.category ?? 'other',
          date: dto.date ? new Date(dto.date) : new Date(),
          createdBy: userId,
          groupId: dto.groupId ?? null,
          clientId: dto.clientId ?? null,
          payers: {
            create: dto.payers.map((p) => ({
              userId: p.userId,
              amount: p.amount,
            })),
          },
          splits: {
            create: dto.splits.map((s) => ({
              userId: s.userId,
              amount: s.amount,
              splitMethod: s.splitMethod,
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
      if (dto.payers?.length) {
        await tx.expensePayer.deleteMany({ where: { expenseId: id } });
        await tx.expensePayer.createMany({
          data: dto.payers.map((p) => ({
            expenseId: id,
            userId: p.userId,
            amount: p.amount,
          })),
        });
      }

      if (dto.splits?.length) {
        await tx.expenseSplit.deleteMany({ where: { expenseId: id } });
        await tx.expenseSplit.createMany({
          data: dto.splits.map((s) => ({
            expenseId: id,
            userId: s.userId,
            amount: s.amount,
            splitMethod: s.splitMethod,
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
        },
        include: {
          payers: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          splits: { include: { user: { select: { id: true, displayName: true, email: true } } } },
          creator: { select: { id: true, displayName: true, email: true } },
        },
      });
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
    const byCategory: Record<string, number> = {};

    for (const exp of expenses) {
      let userAmount: number;
      if (exp.groupId) {
        const split = exp.splits.find((s) => s.userId === userId);
        userAmount = split?.amount ?? 0;
      } else {
        userAmount = exp.totalAmount;
      }
      totalSpent += userAmount;
      byCategory[exp.category] = (byCategory[exp.category] ?? 0) + userAmount;
    }

    return { totalSpent, byCategory, expenseCount: expenses.length };
  }
}
