import { Injectable } from '@nestjs/common/decorators';
import { DataSource, Repository } from 'typeorm';
import { CommentPostDto } from './dtos/comment-post.dto';
import { User } from 'src/user/entity/user.entity';
import { Comment } from './entity/comment.entity';
import { CommentGetDto } from './dtos/comment-get.dto';

const DEFAULT_GET_COMMENT_TAKE = 100;

@Injectable()
export class CommentRepository extends Repository<Comment> {
  constructor(private dataSource: DataSource) {
    super(Comment, dataSource.createEntityManager());
  }

  async getComment(dto: CommentGetDto): Promise<Comment[]> {
    return await this.find({
      select: {
        id: true,
        user: {
          userAppId: true,
        },
        body: true,
        createdAt: true,
        parent: {
          id: true,
        },
      },
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
