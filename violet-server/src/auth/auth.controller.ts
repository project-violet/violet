import {
  Body,
  Controller,
  Delete,
  Get,
  Post,
  Redirect,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiCreatedResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { UserRegisterDTO } from 'src/user/dtos/user-register.dto';
import { User } from 'src/user/entity/user.entity';
import { AuthService } from './auth.service';
import { AccessTokenGuard } from './guards/access-token.guard';
import { Tokens } from './jwt/jwt.token';
import { Request, Response } from 'express';
import { ResLoginUser } from './dtos/res-login-user.dto';
import { plainToClass } from 'class-transformer';
import { HmacAuthGuard } from './guards/hmac.guard';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly configService: ConfigService,
    private readonly authService: AuthService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Get current user information' })
  @ApiCreatedResponse({ description: 'User Information', type: User })
  @UseGuards(AccessTokenGuard)
  getCurrentUser(@CurrentUser() currentUser: User): User {
    return plainToClass(User, currentUser);
  }

  @Post()
  @UseGuards(HmacAuthGuard)
  @ApiOperation({ summary: 'Login' })
  @ApiCreatedResponse({ description: 'jwt token', type: Tokens })
  @Redirect('violet://login')
  async logIn(
    @Body() dto: UserRegisterDTO,
    @Res({ passthrough: true }) res: Response,
  ): Promise<void> {
    const { tokens } = await this.authService.verifyUserAndSignJWT(dto);

    res.cookie('jwt-access', tokens.accessToken, { httpOnly: true });
    res.cookie('jwt-refresh', tokens.refreshToken, { httpOnly: true });
  }

  @Get('/refresh')
  @ApiOperation({ summary: 'Get refresh token' })
  async refreshToken(
    @Req() req: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<ResLoginUser> {
    const accessExpires = new Date(
      Date.now() + Number(this.configService.get<string>('ACCESS_EXPIRES')),
    );
    const refreshExpires = new Date(
      Date.now() + Number(this.configService.get<string>('REFRESH_EXPIRES')),
    );
    const resRefreshData = await this.authService.refreshTokens(
      req.cookies['jwt-refresh'],
    );

    response.cookie('jwt-access', resRefreshData.tokens.accessToken, {
      expires: accessExpires,
      httpOnly: true,
    });
    response.cookie('jwt-refresh', resRefreshData.tokens.refreshToken, {
      expires: refreshExpires,
      httpOnly: true,
    });

    response.cookie('refresh-expires', refreshExpires, {
      httpOnly: false,
      expires: refreshExpires,
    });
    response.cookie('access-expires', refreshExpires, {
      expires: accessExpires,
      httpOnly: false,
    });

    return resRefreshData;
  }

  @Delete()
  @UseGuards(AccessTokenGuard)
  @ApiOperation({ summary: 'Logout' })
  async logout(
    @CurrentUser('userAppId') userAppId: string,
    @Res() res: Response,
  ) {
    await this.authService.deleteRefreshToken(userAppId);
    res.clearCookie('jwt-access');
    res.clearCookie('jwt-refresh');
    res.clearCookie('access-expires');
    res.clearCookie('refresh-expires');
    res.send();
  }
}
