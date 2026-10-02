import { IsEmail, IsString, Length, IsOptional, IsIn, ValidateIf } from 'class-validator';

export class VerifyOtpDto {
  @ValidateIf((o) => typeof o.email === 'string' && o.email.trim().length > 0)
  @IsEmail()
  email?: string;

  @IsString()
  @Length(6, 6)
  otp: string;

  @IsOptional()
  @IsIn(['email_verify', 'password_reset'])
  purpose?: 'email_verify' | 'password_reset' = 'email_verify';
}
