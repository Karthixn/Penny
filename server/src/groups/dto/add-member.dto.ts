import { IsUUID, IsOptional, IsString } from 'class-validator';

export class AddMemberDto {
  @IsUUID()
  userId!: string;

  @IsOptional()
  @IsString()
  role?: string;
}
