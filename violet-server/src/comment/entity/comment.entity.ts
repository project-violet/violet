import { ApiProperty } from '@nestjs/swagger';
import { CoreEntity } from 'src/common/entities/core.entity';
import { User } from 'src/user/entity/user.entity';
import {
  OneToMany,
  JoinColumn,
  Column,
  Entity,
  ManyToOne,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity()
export class Comment extends CoreEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @ApiProperty({
    description: 'User Id',
    required: true,
  })
  @ManyToOne(() => User, (user) => user.userAppId)
  @JoinColumn({ name: 'userAppId' })
  user: User;

  @Column()
  @Index()
  where: string;

  @Column()
  body: string;

  @ManyToOne(() => Comment, (comment) => comment.id)
  @JoinColumn({ name: 'childs' })
  parent?: Comment;

  @OneToMany(() => Comment, (comment) => comment.id)
  childs: Comment[];
}
