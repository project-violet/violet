import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { UserRepository } from './user.repository';
import { UserRegisterDTO } from './dtos/user-register.dto';

@Injectable()
export class UserService {
  constructor(private readonly userRepository: UserRepository) {}

  async registerUser(
    dto: UserRegisterDTO,
  ): Promise<{ ok: boolean; err?: string }> {
    try {
      if (await this.userRepository.isUserExists(dto.userAppId))
        throw new UnauthorizedException('user app id already exists');

      await this.userRepository.createUser(dto);

      return { ok: true };
    } catch (e) {
      Logger.error(e);

      return { ok: false, err: e };
    }
  }
}
