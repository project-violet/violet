import { Injectable, Logger } from '@nestjs/common';
import { CommentPostDto } from './dtos/comment-post.dto';
import { User } from 'src/user/entity/user.entity';
import { CommentRepository } from './comment.repository';
import {
  CommentGetDto,
  CommentGetResponseDto,
  CommentGetResponseDtoElement,
} from './dtos/comment-get.dto';

const DEFAULT_GET_COMMENT_TAKE = 100;

@Injectable()
export class CommentService {
  constructor(private repository: CommentRepository) {}

  async getComment(dto: CommentGetDto): Promise<CommentGetResponseDto> {
    try {
      const comments = await this.repository.find({
        where: {
          where: dto.where,
        },
        take: DEFAULT_GET_COMMENT_TAKE,
        order: {
          id: 'DESC',
        },
        relations: {
          user: true,
          parent: true,
        },
      });

      return { elements: comments.map(CommentGetResponseDtoElement.from) };
    } catch (e) {
      Logger.error(e);

      throw e;
    }
  }

  async postComment(
    user: User,
    dto: CommentPostDto,
  ): Promise<{ ok: boolean; err?: string }> {
    try {
      await this.repository.createComment(user, dto);

      return { ok: true };
    } catch (e) {
      Logger.error(e);

      return { ok: false, err: e };
    }
  }
}
