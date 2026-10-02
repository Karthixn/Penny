import {
  IsString,
  IsInt,
  IsOptional,
  IsUUID,
  IsDateString,
  IsArray,
  ValidateNested,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class PayerDto {
  @IsUUID()
  userId!: string;

  @IsInt()
  @Min(1)
  amount!: number;
}

export class SplitDto {
  @IsUUID()
  userId!: string;

  @IsInt()
  @Min(0)
  amount!: number;

  @IsString()
  splitMethod!: string;
}

export class ExpenseItemDto {
  @IsString()
  name!: string;

  @IsInt()
  @Min(1)
  amount!: number;

  @IsArray()
  @IsUUID('4', { each: true })
  assigneeIds!: string[];
}

export class CreateExpenseDto {
  @IsString()
  description!: string;

  @IsInt()
  @Min(1)
  totalAmount!: number;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsUUID()
  groupId?: string;

  @IsOptional()
  @IsUUID()
  clientId?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PayerDto)
  payers!: PayerDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SplitDto)
  splits!: SplitDto[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ExpenseItemDto)
  items?: ExpenseItemDto[];
}
