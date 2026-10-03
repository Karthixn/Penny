import { IsUUID, IsInt, Min, IsOptional, IsString } from 'class-validator';

export class CreateSettlementDto {
  @IsUUID()
  groupId!: string;

  @IsOptional()
  @IsUUID()
  payerId?: string;

  @IsUUID()
  payeeId!: string;

  @IsInt()
  @Min(1)
  amount!: number;

  @IsOptional()
  @IsString()
  note?: string;
}
