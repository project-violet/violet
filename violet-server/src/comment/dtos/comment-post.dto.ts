import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsString, Matches } from 'class-validator';

export class CommentPostDto {
  @IsString()
  @ApiProperty({
    description: 'Where to post',
    required: true,
  })
  @Type(() => String)
  @Matches(`^(general|\d+)$`, 'i')
  where: string;

  @IsString()
  @ApiProperty({
    description: 'Post Body',
    required: true,
  })
  @Type(() => String)
  body: string;

  @IsString()
  @ApiProperty({
    description: 'Parent Comment',
    required: false,
  })
  @Type(() => Number)
  parent?: number;
}
