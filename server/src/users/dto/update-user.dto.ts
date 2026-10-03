import { IsOptional, IsString, MaxLength, IsInt, Min } from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  displayName?: string;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  monthlyBudget?: number;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  upiId?: string;
}
