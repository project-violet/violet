import { ApiProperty } from '@nestjs/swagger';
import { CoreEntity } from 'src/common/entities/core.entity';
import {
  OneToMany,
  JoinColumn,
  Column,
  Entity,
  ManyToOne,
  Index,
} from 'typeorm';
import { User } from 'src/user/entity/user.entity';

@Entity()
export class Comment extends CoreEntity {
  @ApiProperty({
    description: 'User Id',
    required: true,
  })
  user: User;

  @Column()
  @Index()
  where: string;

  @Column()
  body: string;

  @ManyToOne(() => Comment, (comment) => comment.id)
  @JoinColumn({ name: 'childs' })
  parent: Comment;

  @OneToMany(() => Comment, (comment) => comment.id)
  childs: Comment[];
}
