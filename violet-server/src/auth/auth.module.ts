import { Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { UserRepository } from 'src/user/user.repository';
import { AccessTokenStrategy } from './jwt/access-token.strategy';
import { RefreshTokenStrategy } from './jwt/refresh-token.strategy';
import { UserModule } from 'src/user/user.module';
import { JwtModule } from '@nestjs/jwt';
import { DiscordStrategy } from './discord/discord.strategy';

@Module({
  imports: [JwtModule.register({}), UserModule],
  providers: [
    AuthService,
    UserRepository,
    AccessTokenStrategy,
    RefreshTokenStrategy,
    DiscordStrategy,
  ],
  controllers: [AuthController],
})
export class AuthModule {}
