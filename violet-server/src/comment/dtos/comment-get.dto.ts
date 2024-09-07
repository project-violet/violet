import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { Comment } from 'src/comment/entity/comment.entity';
import {
  IsArray,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';

export class CommentGetDto {
  @IsString()
  @ApiProperty({
    description: 'Where to get',
    required: true,
  })
  @Type(() => String)
  @Matches(`^(general|\d+)$`, 'i')
  where: string;
}

export class CommentGetResponseDtoElement {
  @IsNumber()
  @ApiProperty({
    description: 'Comment Id',
    required: true,
  })
  id: number;

  @IsString()
  @ApiProperty({
    description: 'Body',
    required: true,
  })
  userAppId: string;

  @IsString()
  @ApiProperty({
    description: 'Body',
    required: true,
  })
  body: string;

  @IsString()
  @ApiProperty({
    description: 'Write DateTime',
    required: true,
  })
  dateTime: Date;

  @IsString()
  @IsOptional()
  @ApiProperty({
    description: 'Parent Comment',
    required: false,
  })
  parent?: number;

  static from(comment: Comment): CommentGetResponseDtoElement {
    return {
      id: comment.id,
      userAppId: comment.user.userAppId,
      body: comment.body,
      dateTime: comment.createdAt,
      parent: comment.parent?.id,
    };
  }
}

export class CommentGetResponseDto {
  @IsArray()
  @ApiProperty({
    description: 'Comment Elements',
    required: true,
  })
  elements: CommentGetResponseDtoElement[];
}
