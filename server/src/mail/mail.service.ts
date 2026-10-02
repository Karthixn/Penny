import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';
import { Resend } from 'resend';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: Transporter | null = null;
  private resend: Resend | null = null;
  private fromEmail: string;

  constructor(private config: ConfigService) {
    const smtpUser = this.config.get<string>('SMTP_USER');
    const smtpPass = this.config.get<string>('SMTP_PASS');
    if (smtpUser && smtpPass) {
      this.transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: smtpUser,
          pass: smtpPass,
        },
      });
      this.logger.log(`Configured Gmail SMTP mailer with ${smtpUser}`);
    }

    const apiKey = this.config.get<string>('RESEND_API_KEY');
    if (apiKey) {
      this.resend = new Resend(apiKey);
    }

    this.fromEmail = this.config.get<string>(
      'SMTP_FROM',
      this.config.get<string>('RESEND_FROM', 'Penny <onboarding@resend.dev>'),
    );
  }

  async sendOtpEmail(toEmail: string, otp: string, purpose: 'email_verify' | 'password_reset' = 'email_verify'): Promise<boolean> {
    const isVerify = purpose === 'email_verify';
    const title = isVerify ? 'Verify your Penny account' : 'Reset your Penny password';
    const subtitle = isVerify
      ? 'Thank you for signing up for Penny. Use the code below to verify your email address.'
      : 'You requested a password reset. Use the code below to reset your password.';

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0C0D14; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0C0D14; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" max-width="500px" style="max-width: 500px; background-color: #191B26; border-radius: 20px; border: 1px solid #2A2D3E; overflow: hidden; padding: 36px 28px;">
          <!-- Logo / Header -->
          <tr>
            <td align="center" style="padding-bottom: 24px;">
              <div style="display: inline-block; background: linear-gradient(135deg, #7C6FF7, #5B4FCF); width: 48px; height: 48px; border-radius: 14px; text-align: center; line-height: 48px; font-size: 24px; color: #FFFFFF; font-weight: 700;">
                ₹
              </div>
              <h2 style="margin: 12px 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700;">Penny</h2>
              <p style="margin: 0; color: #8E91A4; font-size: 14px;">Smart Expense Tracking & Split</p>
            </td>
          </tr>

          <!-- Message -->
          <tr>
            <td align="center" style="padding-bottom: 28px;">
              <h3 style="margin: 0 0 10px 0; color: #FFFFFF; font-size: 18px; font-weight: 600;">${title}</h3>
              <p style="margin: 0; color: #8E91A4; font-size: 14px; line-height: 1.5;">${subtitle}</p>
            </td>
          </tr>

          <!-- OTP Box -->
          <tr>
            <td align="center" style="padding-bottom: 28px;">
              <div style="background-color: #0C0D14; border: 1px solid #7C6FF7; border-radius: 12px; padding: 18px 24px; display: inline-block;">
                <span style="font-family: monospace; font-size: 36px; font-weight: 700; letter-spacing: 8px; color: #9D93FA;">${otp}</span>
              </div>
              <p style="margin: 12px 0 0 0; color: #5A5D6E; font-size: 12px;">This code expires in <strong>10 minutes</strong>.</p>
            </td>
          </tr>

          <!-- Footer warning -->
          <tr>
            <td align="center" style="border-top: 1px solid #2A2D3E; padding-top: 20px;">
              <p style="margin: 0; color: #5A5D6E; font-size: 12px; line-height: 1.4;">
                If you didn't request this code, you can safely ignore this email. Someone may have entered your email by mistake.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;

    this.logger.log(`\n========================================\n[OTP GENERATED] To: ${toEmail}\nPurpose: ${purpose}\nCode: >>> ${otp} <<<\nExpires in: 10 minutes\n========================================`);

    // 1. Try Gmail SMTP first (delivers to ANY email in the world)
    if (this.transporter) {
      try {
        const info = await this.transporter.sendMail({
          from: this.fromEmail,
          to: toEmail,
          subject: `Your Penny Verification Code: ${otp}`,
          html,
        });
        this.logger.log(`OTP successfully sent to ${toEmail} via Gmail SMTP (ID: ${info.messageId})`);
        return true;
      } catch (err: any) {
        this.logger.error(`Failed to send email via Gmail SMTP: ${err?.message || err}`);
      }
    }

    // 2. Try Resend if configured
    if (this.resend) {
      try {
        const response = await this.resend.emails.send({
          from: this.fromEmail,
          to: toEmail,
          subject: `Your Penny Verification Code: ${otp}`,
          html,
        });
        if (response.error) {
          this.logger.error(`Resend email error: ${JSON.stringify(response.error)}`);
          return false;
        }
        this.logger.log(`OTP successfully sent to ${toEmail} via Resend (ID: ${response.data?.id})`);
        return true;
      } catch (err: any) {
        this.logger.error(`Failed to send email via Resend: ${err?.message || err}`);
        return false;
      }
    }

    return true;
  }
}
