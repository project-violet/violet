import { ExtractJwt, Strategy } from 'passport-jwt';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { jwtExtractorFromCookies } from './jwtExtractorFromCookies';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { UserRepository } from 'src/user/user.repository';
import { JwtPayload } from './jwt.payload';

// guard -> strategy -> validate
@Injectable()
export class RefreshTokenStrategy extends PassportStrategy(
  Strategy,
  'jwt-refresh',
) {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly configService: ConfigService,
  ) {
    super({
      jwtFromRequest:
        process.env.NODE_ENV === 'dev'
          ? ExtractJwt.fromAuthHeaderAsBearerToken()
          : ExtractJwt.fromExtractors([jwtExtractorFromCookies]),
      secretOrKey: configService.get<string>('REFRESH_TOKEN_SECRET_KEY'),
      passReqToCallback: true,
    });
  }

  async validate(req: Request, payload: JwtPayload) {
    try {
      console.log('validation');
      const refreshToken = req.cookies['jwt-refresh'];
      const user = await this.userRepository.findOneBy({
        userAppId: payload.userAppId,
      });
      if (user) {
        user.refreshToken = refreshToken;
        return user;
      } else {
        throw new Error('Retry after login');
      }
    } catch (error) {
      throw new UnauthorizedException(error);
    }
  }
}
