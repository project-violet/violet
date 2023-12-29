import { Module } from '@nestjs/common';
import { ViewController } from './view.controller';
import { ViewService } from './view.service';
import { RedisService } from 'src/redis/redis.service';

@Module({
  controllers: [ViewController],
  providers: [RedisService, ViewService],
})
export class ViewModule {}
