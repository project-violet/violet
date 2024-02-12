import { RedisService as RedisInnerService } from '@songkeys/nestjs-redis';
import { Inject, Injectable, Logger } from '@nestjs/common';
import Redis from 'ioredis';

@Injectable()
export class RedisService {
  private readonly redis: Redis;

  constructor(private readonly redisService: RedisInnerService) {
    this.redis = this.redisService.getClient();
    this.subcribe_close_event();
  }

  async subcribe_close_event() {
    await this.redis.psubscribe('*', function (e) {});
    this.redis.on('pmessage', function (pattern, message, channel) {
      console.log(message, channel);
      if (
        message.toString().startsWith('__keyevent') &&
        message.toString().endsWith('expired')
      ) {
        // This method must called only one per keyevent.
        Logger.log(`expired ${channel}`);
        const type = channel.split('-')[0];
        const id = channel.split('-')[1];
        if (
          (type == 'weekly' || type == 'daily' || type == 'monthly') &&
          isNumeric(id)
        ) {
          this.redis.zincrby(type, -1, id);
        }
      }
    });
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

function isNumeric(str: unknown): boolean {
  return !isNaN(Number(str));
}
