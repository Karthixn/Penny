import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module.js';
import { AuthModule } from './auth/auth.module.js';
import { UsersModule } from './users/users.module.js';
import { ExpensesModule } from './expenses/expenses.module.js';
import { GroupsModule } from './groups/groups.module.js';
import { SettlementsModule } from './settlements/settlements.module.js';
import { RemindersModule } from './reminders/reminders.module.js';
import { MailModule } from './mail/mail.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    MailModule,
    AuthModule,
    UsersModule,
    ExpensesModule,
    GroupsModule,
    SettlementsModule,
    RemindersModule,
  ],
})
export class AppModule {}
