import { Injectable } from '@nestjs/common/decorators';
import { DataSource, Repository } from 'typeorm';
import { CommentPostDto } from './dtos/comment-post.dto';
import { User } from 'src/user/entity/user.entity';
import { Comment } from './entity/comment.entity';

@Injectable()
export class CommentRepository extends Repository<Comment> {
  constructor(private dataSource: DataSource) {
    super(Comment, dataSource.createEntityManager());
  }

  async createComment(user: User, dto: CommentPostDto): Promise<Comment> {
    const { parent, where, body } = dto;
    const comment = this.create({ parent: { id: parent }, user, where, body });
    try {
      await this.save(comment);
      return comment;
    } catch (error) {
      throw new Error(error);
    }
  }
}
