import { Injectable } from '@nestjs/common/decorators';
import { DataSource, Repository } from 'typeorm';
import { View } from './entity/view.entity';
import { ViewPostRequestDto } from './dtos/view-post.dto';

@Injectable()
export class ViewRepository extends Repository<View> {
  constructor(private dataSource: DataSource) {
    super(View, dataSource.createEntityManager());
  }

  async postView(dto: ViewPostRequestDto): Promise<View> {
    const { userAppId, viewSeconds, articleId } = dto;
    const view = this.create({ userAppId, viewSeconds, articleId });
    try {
      await this.save(view);
      return view;
    } catch (error) {
      throw new Error(error);
    }
  }
}
