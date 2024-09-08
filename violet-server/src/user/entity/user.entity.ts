import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty } from 'class-validator';
import { CoreEntity } from 'src/common/entities/core.entity';
import { Column, Entity, OneToMany, Index } from 'typeorm';
import { Exclude } from 'class-transformer';
import { Comment } from 'src/comment/entity/comment.entity';

@Entity()
export class User extends CoreEntity {
  @ApiProperty({
    description: 'User Id',
    required: true,
  })
  @IsNotEmpty({ message: 'User id is required for register.' })
  @Column({ unique: true })
  userAppId: string;

  @Column({ nullable: true })
  @Index()
  discordId?: string;

  @Column({ nullable: true })
  avatar?: string;

  @Column({ unique: true, nullable: true })
  nickname?: string;

  @Column({ nullable: true })
  @Exclude()
  @Index()
  refreshToken?: string;

  @OneToMany(() => Comment, (comment) => comment.user)
  comments: Comment[];
}
