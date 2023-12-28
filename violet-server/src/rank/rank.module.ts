import { Module } from '@nestjs/common';
import { RankController } from './rank.controller';
import { RankService } from './rank.service';
import { RedisService } from 'src/redis/redis.service';

@Module({
  controllers: [RankController],
  providers: [RedisService, RankService],
})
export class RankModule {}
