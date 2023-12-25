import { Logger } from '@nestjs/common';
import { Request } from 'express';
import { JwtFromRequestFunction } from 'passport-jwt';

export const jwtExtractorFromCookies: JwtFromRequestFunction = (
  request: Request,
): string | null => {
  try {
    const jwt = request.cookies['jwt-access'];
    return jwt;
  } catch (error) {
    console.log(error);
    Logger.log('Invalid Error', jwtExtractorFromCookies);
    return null;
  }
};
