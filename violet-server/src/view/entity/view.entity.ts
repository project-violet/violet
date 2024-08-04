import { CoreEntity } from 'src/common/entities/core.entity';
import { Column, Entity, Index } from 'typeorm';

@Entity()
export class View extends CoreEntity {
  @Column()
  @Index()
  userAppId: string;

  @Column()
  articleId: number;

  @Column()
  viewSeconds: number;
}
