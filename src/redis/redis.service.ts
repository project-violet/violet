import { RedisService as RedisInnerService } from '@songkeys/nestjs-redis';
import { Inject, Injectable } from '@nestjs/common';
import Redis from 'ioredis';

@Injectable()
export class RedisService {
  private readonly redis: Redis;

  constructor(private readonly redisService: RedisInnerService) {
    this.redis = this.redisService.getClient();
  }

  async get(key: string): Promise<string> {
    return this.redis.get(key);
  }

  async set(key: string, value: string, expireTime?: number) {
    await this.redis.set(key, value, 'EX', expireTime ?? 10);
  }

  async zrevrange_by_score(
    group: string,
    offset: number,
    count: number,
  ): Promise<string[]> {
    return await this.redis.zrevrange(group, offset, count, 'WITHSCORES');
  }

  async zincrby(
    group: string,
    increment: number,
    member: number,
  ): Promise<string> {
    return await this.redis.zincrby(group, increment, member);
  }

  async setex(group: string, seconds: number, value: string): Promise<void> {
    await this.redis.setex(group, seconds, value);
  }
}
