import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateReminderDto } from './dto/create-reminder.dto.js';
import { UpdateReminderDto } from './dto/update-reminder.dto.js';

@Injectable()
export class RemindersService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, dto: CreateReminderDto) {
    return this.prisma.reminder.create({
      data: {
        userId,
        title: dto.title,
        amount: dto.amount ?? null,
        dueDate: new Date(dto.dueDate),
        isRecurring: dto.isRecurring ?? false,
        recurrenceRule: dto.recurrenceRule ?? null,
      },
    });
  }

  async findAll(userId: string) {
    return this.prisma.reminder.findMany({
      where: { userId, completedAt: null },
      orderBy: { dueDate: 'asc' },
    });
  }

  async findOne(userId: string, id: string) {
    const reminder = await this.prisma.reminder.findFirst({
      where: { id, userId },
    });
    if (!reminder) throw new NotFoundException();
    return reminder;
  }

  async update(userId: string, id: string, dto: UpdateReminderDto) {
    const reminder = await this.prisma.reminder.findFirst({ where: { id, userId } });
    if (!reminder) throw new NotFoundException();

    return this.prisma.reminder.update({
      where: { id },
      data: {
        ...(dto.title && { title: dto.title }),
        ...(dto.amount !== undefined && { amount: dto.amount }),
        ...(dto.dueDate && { dueDate: new Date(dto.dueDate) }),
        ...(dto.isRecurring !== undefined && { isRecurring: dto.isRecurring }),
        ...(dto.recurrenceRule !== undefined && { recurrenceRule: dto.recurrenceRule }),
      },
    });
  }

  async complete(userId: string, id: string) {
    const reminder = await this.prisma.reminder.findFirst({ where: { id, userId } });
    if (!reminder) throw new NotFoundException();

    if (reminder.isRecurring && reminder.recurrenceRule) {
      const nextDate = this.getNextOccurrence(reminder.dueDate, reminder.recurrenceRule);
      await this.prisma.reminder.update({
        where: { id },
        data: { dueDate: nextDate },
      });
      return this.findOne(userId, id);
    }

    return this.prisma.reminder.update({
      where: { id },
      data: { completedAt: new Date() },
    });
  }

  async remove(userId: string, id: string) {
    const reminder = await this.prisma.reminder.findFirst({ where: { id, userId } });
    if (!reminder) throw new NotFoundException();
    await this.prisma.reminder.delete({ where: { id } });
  }

  private getNextOccurrence(current: Date, rule: string): Date {
    const next = new Date(current);
    switch (rule) {
      case 'daily':
        next.setDate(next.getDate() + 1);
        break;
      case 'weekly':
        next.setDate(next.getDate() + 7);
        break;
      case 'monthly':
        next.setMonth(next.getMonth() + 1);
        break;
      case 'yearly':
        next.setFullYear(next.getFullYear() + 1);
        break;
      default:
        next.setMonth(next.getMonth() + 1);
    }
    return next;
  }
}
