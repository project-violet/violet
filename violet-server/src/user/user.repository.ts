import { Injectable } from '@nestjs/common/decorators';
import { DataSource, Repository } from 'typeorm';
import { UserRegisterDTO } from './dtos/user-register.dto';
import { User } from './entity/user.entity';

@Injectable()
export class UserRepository extends Repository<User> {
  constructor(private dataSource: DataSource) {
    super(User, dataSource.createEntityManager());
  }

  async isUserExists(userAppId: string): Promise<boolean> {
    return (
      (await this.findOneBy({
        userAppId,
      })) !== null
    );
  }

  async createUser(dto: UserRegisterDTO): Promise<User> {
    const { userAppId } = dto;
    const user = this.create({ userAppId });
    try {
      await this.save(user);
      return user;
    } catch (error) {
      throw new Error(error);
    }
  }
}
