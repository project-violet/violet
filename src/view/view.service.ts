import { Injectable } from '@nestjs/common';
import { ViewGetRequestDto, ViewGetResponseDto } from './dtos/view-get.dto';
import { RedisService } from 'src/redis/redis.service';
import { ViewPostRequestDto } from './dtos/view-post.dto';
import { User } from 'src/user/entity/user.entity';

@Injectable()
export class ViewService {
  constructor(private redisService: RedisService) {}

  async getView(dto: ViewGetRequestDto): Promise<ViewGetResponseDto> {
    let v = await this.redisService.zrevrange_by_score(
      dto.type ?? 'daily',
      dto.offset,
      dto.count,
    );
    return {
      test: v,
    };
  }

  post(dto: ViewPostRequestDto) {
    this.postRedis(dto.articleId);
  }

  async postLogined(user: User, dto: ViewPostRequestDto) {
    this.postRedis(dto.articleId);
  }

  postRedis(articleId: number) {
    const now = new Date();
    const keyName = articleId.toString() + '-' + now;

    this.redisService.zincrby('alltime', 1, articleId);

    this.redisService.zincrby('daily', 1, articleId);
    this.redisService.setex(`daily-${keyName}`, 1 * 60 * 60 * 24, '1');

    this.redisService.zincrby('weekly', 1, articleId);
    this.redisService.setex(`weekly-${keyName}`, 7 * 60 * 60 * 24, '1');

    this.redisService.zincrby('monthly', 1, articleId);
    this.redisService.setex(`monthly-${keyName}`, 30 * 60 * 60 * 24, '1');
  }
}
