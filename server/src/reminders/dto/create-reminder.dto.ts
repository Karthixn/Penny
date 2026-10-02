import { IsString, IsOptional, IsInt, IsBoolean, IsDateString, Min } from 'class-validator';

export class CreateReminderDto {
  @IsString()
  title!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  amount?: number;

  @IsDateString()
  dueDate!: string;

  @IsOptional()
  @IsBoolean()
  isRecurring?: boolean;

  @IsOptional()
  @IsString()
  recurrenceRule?: string;
}
