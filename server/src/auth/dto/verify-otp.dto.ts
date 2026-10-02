import { IsEmail, IsString, Length, IsOptional, IsIn } from 'class-validator';

export class VerifyOtpDto {
  @IsEmail()
  email: string;

  @IsString()
  @Length(6, 6)
  otp: string;

  @IsOptional()
  @IsIn(['email_verify', 'password_reset'])
  purpose?: 'email_verify' | 'password_reset' = 'email_verify';
}
