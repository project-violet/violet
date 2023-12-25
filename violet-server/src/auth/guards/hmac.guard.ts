import {
  Injectable,
  CanActivate,
  ExecutionContext,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

@Injectable()
export class HmacAuthGuard implements CanActivate {
  constructor(private configService: ConfigService) {}

  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    const token = request.headers['v-token'];
    const valid = request.headers['v-valid'];

    if (token == null || valid == null) {
      // logger.info('auth: token or valid is null');
      throw new BadRequestException();
    }

    const clientTimestamp = parseInt(token);

    if (isNaN(clientTimestamp)) {
      // logger.info('auth: token is not int');
      throw new BadRequestException();
    }

    const serverTimestamp = new Date().getTime();

    if (Math.abs(serverTimestamp - clientTimestamp) > 30000) {
      // logger.info(
      //   'auth: timestamp error, st=%d, ct=%d',
      //   serverTimestamp,
      //   clientTimestamp,
      // );
      throw new BadRequestException();
    }

    return this.authTest(token, valid, this.configService.get<string>('SALT'));
  }

  authTest(token, valid, salt) {
    const mac = crypto.createHash('sha512');
    const hmac = mac.update(token + salt);
    const hash = hmac.digest('hex').substr(0, 7);

    return hash == valid;
  }
}
