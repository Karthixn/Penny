import { IsEmail, IsOptional, IsIn, ValidateIf } from 'class-validator';

export class SendOtpDto {
  @ValidateIf((o) => typeof o.email === 'string' && o.email.trim().length > 0)
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsIn(['email_verify', 'password_reset'])
  purpose?: 'email_verify' | 'password_reset' = 'email_verify';
}
