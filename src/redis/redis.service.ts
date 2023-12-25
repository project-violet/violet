import { RedisService as RedisInnerService } from '@songkeys/nestjs-redis';
import { Inject, Injectable } from '@nestjs/common';
import Redis from 'ioredis';

@Injectable()
export class RedisService {
  private readonly redis: Redis;

  constructor(private readonly redisService: RedisInnerService) {
    this.redis = redisService.getClient();
  }

  async get(key: string): Promise<string> {
    return this.redis.get(key);
  }

  async set(key: string, value: string, expireTime?: number) {
    this.redis.set(key, value, 'EX', expireTime ?? 10);
  }
}
