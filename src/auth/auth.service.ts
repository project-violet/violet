import { BadRequestException, HttpException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserRegisterDTO } from 'src/user/dtos/user-register.dto';
import { UserRepository } from 'src/user/user.repository';
import { ResLoginUser } from './dtos/res-login-user.dto';
import { Tokens } from './jwt/jwt.token';

@Injectable()
export class AuthService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async verifyUserAndSignJWT(dto: UserRegisterDTO): Promise<ResLoginUser> {
    const user = await this.userRepository.findOneBy({
      userAppId: dto.userAppId,
    });
    if (!user) {
      throw new BadRequestException('User app id is not found');
    }
    try {
      const tokens = await this.createJWT(user.userAppId);
      await this.updateRefreshToken(user.userAppId, tokens.refreshToken);

      return { user, tokens };
    } catch (error) {
      throw new BadRequestException(error.message);
    }
  }

  async login(dto: UserRegisterDTO) {
    const payload = { username: dto.userAppId };
    return {
      access_token: this.jwtService.sign(payload),
    };
  }

  async createJWT(userAppId: string): Promise<Tokens> {
    const accessExpires = Number(
      new Date(
        Date.now() + Number(this.configService.get<string>('ACCESS_EXPIRES')),
      ),
    );
    const refreshExpires = Number(
      new Date(
        Date.now() + Number(this.configService.get<string>('REFRESH_EXPIRES')),
      ),
    );
    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(
        {
          userAppId,
        },
        {
          secret: this.configService.get<string>('ACCESS_TOKEN_SECRET_KEY'),
          expiresIn: accessExpires,
        },
      ),
      this.jwtService.signAsync(
        {
          userAppId,
        },
        {
          secret: this.configService.get<string>('REFRESH_TOKEN_SECRET_KEY'),
          expiresIn: refreshExpires,
        },
      ),
    ]);

    return { accessToken, refreshToken };
  }

  async updateRefreshToken(userAppId: string, refreshToken: string) {
    await this.userRepository.update({ userAppId }, { refreshToken });
  }

  async refreshTokens(refreshToken: string): Promise<ResLoginUser> {
    const user = await this.userRepository.findOneBy({
      refreshToken: refreshToken,
    });

    if (!user) {
      throw new HttpException('Invalid Token', 401);
    }

    const tokens = await this.createJWT(user.userAppId);
    await this.updateRefreshToken(user.userAppId, tokens.refreshToken);

    return { tokens, user };
  }

  async deleteRefreshToken(userAppId: string) {
    await this.userRepository.update({ userAppId }, { refreshToken: null });
  }
}
