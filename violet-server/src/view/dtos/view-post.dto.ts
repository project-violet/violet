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

export class ViewPostRequestDto {
  @IsNumber()
  @Type(() => Number)
  @ApiProperty({
    description: 'ArticleId',
    required: true,
  })
  articleId: number;

  @IsNumber()
  @Type(() => Number)
  @Min(0)
  @Max(1000)
  @ApiProperty({
    description: 'Count',
    required: true,
  })
  viewSeconds: number;

  @IsString()
  @ApiProperty({
    description: 'User App Id',
    required: true,
  })
  userAppId: string;
}
