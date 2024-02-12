import { Module } from '@nestjs/common';
import { ViewController } from './view.controller';
import { ViewService } from './view.service';
import { RedisService } from 'src/redis/redis.service';
import { ViewRepository } from './view.repository';

@Module({
  controllers: [ViewController],
  providers: [RedisService, ViewService, ViewRepository],
})
export class ViewModule {}
