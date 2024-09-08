import {
  BadRequestException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { UserRepository } from './user.repository';
import { UserRegisterDTO } from './dtos/user-register.dto';

@Injectable()
export class UserService {
  constructor(private readonly userRepository: UserRepository) {}

  async registerUser(
    dto: UserRegisterDTO,
  ): Promise<{ ok: boolean; error?: string }> {
    try {
      if (await this.userRepository.isUserExists(dto.userAppId))
        throw new UnauthorizedException('user app id already exists');

      await this.userRepository.createUser(dto);

      return { ok: true };
    } catch (e) {
      Logger.error(e);

      return { ok: false, error: e };
    }
  }

  async listDiscordUserAppIds(discordId?: string): Promise<string[]> {
    if (discordId == null) {
      throw new BadRequestException('discord login is required');
    }

    const users = await this.userRepository.find({
      select: {
        userAppId: true,
      },
      where: {
        discordId: discordId!,
      },
    });

    return users.map(({ userAppId }) => userAppId);
  }
}
