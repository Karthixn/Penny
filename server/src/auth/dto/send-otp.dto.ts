import { IsEmail, IsOptional, IsIn } from 'class-validator';

export class SendOtpDto {
  @IsEmail()
  email: string;

  @IsOptional()
  @IsIn(['email_verify', 'password_reset'])
  purpose?: 'email_verify' | 'password_reset' = 'email_verify';
}
