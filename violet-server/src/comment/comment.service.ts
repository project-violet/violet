import { Injectable } from '@nestjs/common';
import { CommentPostDto } from './dtos/comment-post.dto';
import { User } from 'src/user/entity/user.entity';
import { CommentRepository } from './comment.repository';

@Injectable()
export class CommentService {
  constructor(private repository: CommentRepository) {}

  postComment(user: User, dto: CommentPostDto) {
    this.repository.createComment(user, dto);
  }
}
