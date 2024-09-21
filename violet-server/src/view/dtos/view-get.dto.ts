import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
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

export class ViewGetRequestDto {
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

export class ViewGetResponseDtoElement {
  @IsNumber()
  @ApiProperty({
    description: 'Article Id',
    required: true,
  })
  articleId: number;

  @IsNumber()
  @ApiProperty({
    description: 'Count',
    required: true,
  })
  count: number;
}

export class ViewGetResponseDto {
  @IsArray()
  @ApiProperty({
    description: 'View Get Elements',
    required: true,
    type: ViewGetResponseDtoElement,
    isArray: true,
  })
  elements: ViewGetResponseDtoElement[];
}
