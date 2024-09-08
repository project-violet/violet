import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { JwtPayload } from 'src/auth/jwt/jwt.payload';

export const CurrentUser = createParamDecorator(
  (data: keyof JwtPayload | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();

    request.user = { ...request.user, ...request.discord };

    const { refreshToken, ...responUser } = request.user;

    if (!data) return responUser;

    return request.user[data];
  },
);
