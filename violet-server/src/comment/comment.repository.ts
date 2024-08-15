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
    // CHECK: 그냥 parent id를 넣는 방법은 없나?
    const parentComment = await this.findOneBy({ id: parent });
    const comment = this.create({ parent: parentComment, user, where, body });
    try {
      await this.save(comment);
      return comment;
    } catch (error) {
      throw new Error(error);
    }
  }
}
