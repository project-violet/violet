import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';

export const RANK_REQUEST_TYPE = {
  DAILY: 'daily',
  WEEKLY: 'weekly',
  MONTHLY: 'monthly',
  ALLTIME: 'alltime',
};

export class RankGetRequestDto {
  @IsNumber()
  @Type(() => Number)
  @Min(0)
  @ApiProperty({
    description: 'Offset',
    required: true,
  })
  offset: number;

  @IsNumber()
  @Type(() => Number)
  @Min(0)
  @Max(1000)
  @ApiProperty({
    description: 'Count',
    required: true,
  })
  count: number;

  @IsString()
  @IsOptional()
  @Matches(`^${Object.values(RANK_REQUEST_TYPE).join('|')}$`, 'i')
  @ApiProperty({ description: 'Type', required: false })
  type?: string = 'alltime';
}

export class RankGetResponseDto {
  test: string[];
}
