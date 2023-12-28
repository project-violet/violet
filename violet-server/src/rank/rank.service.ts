import { Injectable } from '@nestjs/common';
import { RankRequestDto, RankResponseDto } from './dtos/rank-get.dto';
import { RedisService } from 'src/redis/redis.service';

@Injectable()
export class RankService {
  constructor(private redisService: RedisService) {}

  async getRank(dto: RankRequestDto): Promise<RankResponseDto> {
    let v = await this.redisService.zrevrange_by_score(
      dto.type ?? 'daily',
      dto.offset,
      dto.count,
    );
    return {
      test: v,
    };
  }
}
