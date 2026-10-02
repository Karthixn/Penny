import { IsUUID, IsInt, Min } from 'class-validator';

export class CreateSettlementDto {
  @IsUUID()
  groupId!: string;

  @IsUUID()
  payeeId!: string;

  @IsInt()
  @Min(1)
  amount!: number;
}
