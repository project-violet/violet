import { Test, TestingModule } from '@nestjs/testing';
import { CommentController } from './comment.controller';
import { UserRepository } from 'src/user/user.repository';
import { ConfigModule } from '@nestjs/config';
import { CommentRepository } from './comment.repository';
import { envValidationSchema } from 'src/app.module';
import { JwtModule } from '@nestjs/jwt';
import { UserModule } from 'src/user/user.module';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { CommentService } from './comment.service';
import { User } from 'src/user/entity/user.entity';
import { Comment } from 'src/comment/entity/comment.entity';

describe('CommentController', () => {
  let module: TestingModule;
  let controller: CommentController;
  let userRepository: UserRepository;

  beforeEach(async () => {
    module = await Test.createTestingModule({
      providers: [CommentRepository, UserRepository, CommentService],
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          envFilePath: '.test.env',
          validationSchema: envValidationSchema,
        }),
        JwtModule.register({}),
        UserModule,
        TypeOrmModule.forRoot({
          type: 'sqlite',
          database: ':memory:',
          entities: [User, Comment],
          synchronize: true,
        }),
      ],
      controllers: [CommentController],
    })
      .overrideGuard(HmacAuthGuard)
      .useValue({ canActivate: jest.fn(() => true) })
      .compile();

    controller = module.get<CommentController>(CommentController);
    userRepository = module.get<UserRepository>(UserRepository);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
    expect(userRepository).toBeDefined();
  });

  it('post comment', async () => {
    let mockUser = await userRepository.createUser({
      userAppId: 'test',
    });
    await controller.postComment(mockUser, {
      where: 'general',
      body: 'test',
    });
  });

  afterEach(async () => {
    await module.close();
  });
});
