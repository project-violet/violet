import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class DiscordAuthGuard extends AuthGuard('discord') {
  constructor() {
    super({
      property: 'discord',
    });
  }

  async canActivate(context: ExecutionContext) {
    return (await super.canActivate(context)) as boolean;
  }

  handleRequest(err: any, user: any) {
    if (err || !user) {
      throw err || new UnauthorizedException('Retry login');
    }
    return user;
  }
}
