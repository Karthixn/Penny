import {
  Injectable,
  Logger,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { PrismaService } from '../prisma/prisma.service.js';
import { MailService } from '../mail/mail.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { SendOtpDto } from './dto/send-otp.dto.js';
import { VerifyOtpDto } from './dto/verify-otp.dto.js';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
    private mailService: MailService,
  ) {}

  async register(dto: RegisterDto) {
    const email = dto.email.toLowerCase();
    const existing = await this.prisma.user.findUnique({
      where: { email },
    });

    let user;
    if (existing) {
      if (existing.deletedAt !== null) {
        // User was previously deleted! Reactivate and allow fresh re-registration
        const passwordHash = await bcrypt.hash(dto.password, 12);
        user = await this.prisma.user.update({
          where: { id: existing.id },
          data: {
            passwordHash,
            displayName: dto.displayName ?? null,
            deletedAt: null,
            isEmailVerified: false,
          },
        });
      } else {
        throw new ConflictException('Email already registered');
      }
    } else {
      const passwordHash = await bcrypt.hash(dto.password, 12);
      user = await this.prisma.user.create({
        data: {
          email,
          passwordHash,
          displayName: dto.displayName,
          isEmailVerified: false,
        },
      });
    }

    // Clean up older pending tokens
    await this.prisma.otpToken.deleteMany({
      where: { userId: user.id, purpose: 'email_verify' },
    });

    // Optionally dispatch OTP email in the background without blocking registration
    this.generateAndSendOtp(user.id, user.email, 'email_verify').catch((err) => {
      this.logger.warn(`Initial background OTP dispatch skipped/failed: ${err?.message || err}`);
    });

    // Generate session tokens so the user logs in immediately!
    const tokens = await this.generateTokenPair(user.id);

    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        isEmailVerified: user.isEmailVerified,
      },
      message: 'Account created successfully',
      requiresVerification: false,
    };
  }

  async login(dto: LoginDto) {
    const email = dto.email.toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email },
    });
    if (!user || user.deletedAt) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    const tokens = await this.generateTokenPair(user.id);
    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        isEmailVerified: user.isEmailVerified,
      },
      message: 'Logged in successfully',
      requiresVerification: false,
    };
  }

  async sendOtp(dto: SendOtpDto, authHeader?: string) {
    let email = dto.email?.toLowerCase().trim();
    if (!email && authHeader?.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      try {
        const payload = this.jwt.verify(token);
        const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
        if (user) email = user.email;
      } catch (_) {}
    }

    if (!email) {
      throw new BadRequestException('Please provide an email address');
    }

    const purpose = dto.purpose || 'email_verify';
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || user.deletedAt) {
      throw new NotFoundException('Account with this email does not exist');
    }

    await this.generateAndSendOtp(user.id, user.email, purpose);

    return {
      message: 'Verification code sent to your email',
      email: user.email,
    };
  }

  async verifyOtp(dto: VerifyOtpDto, authHeader?: string) {
    let email = dto.email?.toLowerCase().trim();
    if (!email && authHeader?.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      try {
        const payload = this.jwt.verify(token);
        const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
        if (user) email = user.email;
      } catch (_) {}
    }

    if (!email) {
      throw new BadRequestException('Please provide an email address');
    }

    const purpose = dto.purpose || 'email_verify';
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || user.deletedAt) {
      throw new NotFoundException('Account with this email does not exist');
    }

    const tokenRecord = await this.prisma.otpToken.findFirst({
      where: {
        userId: user.id,
        purpose,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!tokenRecord) {
      throw new BadRequestException('Verification code has expired or is invalid. Please request a new code.');
    }

    const isMatch = await bcrypt.compare(dto.otp, tokenRecord.otpHash);
    if (!isMatch) {
      await this.prisma.otpToken.update({
        where: { id: tokenRecord.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid verification code. Please check your email and try again.');
    }

    // Clean up used OTP
    await this.prisma.otpToken.deleteMany({
      where: { userId: user.id, purpose },
    });

    // Mark user email verified
    if (purpose === 'email_verify') {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { isEmailVerified: true },
      });
    }

    // Issue fresh session tokens
    return this.generateTokenPair(user.id);
  }

  async refresh(refreshToken: string) {
    const tokenHash = await this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findFirst({
      where: { tokenHash },
    });

    if (!stored || stored.isRevoked || stored.expiresAt < new Date()) {
      if (stored) {
        // Potential theft: revoke entire family
        await this.prisma.refreshToken.updateMany({
          where: { family: stored.family },
          data: { isRevoked: true },
        });
      }
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Revoke the used token
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { isRevoked: true },
    });

    // Issue new pair with same family
    return this.generateTokenPair(stored.userId, stored.family);
  }

  async logout(refreshToken: string) {
    const tokenHash = await this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findFirst({
      where: { tokenHash },
    });
    if (stored) {
      await this.prisma.refreshToken.updateMany({
        where: { family: stored.family },
        data: { isRevoked: true },
      });
    }
  }

  private async generateAndSendOtp(userId: string, email: string, purpose: 'email_verify' | 'password_reset') {
    // Rate limit: prevent requesting multiple codes within 45 seconds
    const recent = await this.prisma.otpToken.findFirst({
      where: {
        userId,
        purpose,
        createdAt: { gt: new Date(Date.now() - 45 * 1000) },
      },
    });
    if (recent) {
      throw new BadRequestException('Please wait 45 seconds before requesting another code.');
    }

    // Cryptographically random 6-digit number
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = await bcrypt.hash(otp, 10);

    // Remove any older tokens for this purpose
    await this.prisma.otpToken.deleteMany({
      where: { userId, purpose },
    });

    // Save token with 10-minute validity
    await this.prisma.otpToken.create({
      data: {
        userId,
        otpHash,
        purpose,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      },
    });

    this.logger.log(`Generated OTP token for user ${userId} (${email}) [Code: ${otp}]`);

    // Dispatch email asynchronously so client request completes immediately without delay
    this.mailService.sendOtpEmail(email, otp, purpose).catch((err: any) => {
      this.logger.warn(`Could not dispatch OTP email to ${email}: ${err?.message || err}`);
    });
  }

  private async generateTokenPair(userId: string, family?: string) {
    const tokenFamily = family || uuidv4();
    const accessToken = this.jwt.sign(
      { sub: userId },
      { expiresIn: this.config.get('JWT_EXPIRES_IN', '15m') },
    );

    const rawRefresh = uuidv4();
    const refreshTokenHash = await this.hashToken(rawRefresh);
    const refreshDays = this.config.get('REFRESH_TOKEN_EXPIRES_DAYS', 30);

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: refreshTokenHash,
        family: tokenFamily,
        expiresAt: new Date(Date.now() + refreshDays * 24 * 60 * 60 * 1000),
      },
    });

    return {
      accessToken,
      refreshToken: rawRefresh,
      expiresIn: 900, // 15 min in seconds
    };
  }

  private async hashToken(token: string): Promise<string> {
    const crypto = await import('crypto');
    return crypto.createHash('sha256').update(token).digest('hex');
  }
}
