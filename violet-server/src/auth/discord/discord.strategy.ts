import { Injectable, UnauthorizedException } from '@nestjs/common';
import { Profile, Strategy } from 'passport-discord';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';

@Injectable()
export class DiscordStrategy extends PassportStrategy(Strategy, 'discord') {
  constructor(private readonly configService: ConfigService) {
    super({
      clientID: configService.get<string>('DISCORD_CLIENT_ID'),
      clientSecret: configService.get<string>('DISCORD_CLIENT_SECRET'),
      callbackURL: 'http://localhost:3000/api/v2/auth/discord/redirect',
      scope: ['identify'],
    });
  }

  async validate(accessToken: string, refreshToken: string, profile: Profile) {
    try {
      const { id: discordId, avatar } = profile;
      return {
        discordId: discordId,
        avatar: avatar,
      };
    } catch (error) {
      throw new UnauthorizedException(error);
    }
  }
}
