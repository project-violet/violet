import { Injectable, Logger } from '@nestjs/common';
import { CommentPostDto } from './dtos/comment-post.dto';
import { User } from 'src/user/entity/user.entity';
import { CommentRepository } from './comment.repository';

@Injectable()
export class CommentService {
  constructor(private repository: CommentRepository) {}

  async getComment(
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
