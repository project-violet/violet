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
  let mockUser: User;

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
          logging: true,
        }),
      ],
      controllers: [CommentController],
    })
      .overrideGuard(HmacAuthGuard)
      .useValue({ canActivate: jest.fn(() => true) })
      .compile();

    controller = module.get<CommentController>(CommentController);
    userRepository = module.get<UserRepository>(UserRepository);

    mockUser = await userRepository.createUser({
      userAppId: 'test',
    });
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
    expect(userRepository).toBeDefined();
  });

  it('post comment', async () => {
    let res = await controller.postComment(mockUser, {
      where: 'general',
      body: 'test',
    });
    expect(res.ok).toBe(true);
  });

  it('get comment', async () => {
    await controller.postComment(mockUser, {
      where: 'general',
      body: 'test',
    });
    let res = await controller.getComment({
      where: 'general',
    });
    expect(res.elements).not.toHaveLength(0);
  });

  it('post comment with parent', async () => {
    await controller.postComment(mockUser, {
      where: 'general',
      body: 'parent',
    });
    let parentComment = await controller.getComment({
      where: 'general',
    });
    let res = await controller.postComment(mockUser, {
      where: 'general',
      body: 'test',
      parent: parentComment.elements[0].id,
    });
    console.log(res);
    expect(res.ok).toBe(true);
  });

  afterEach(async () => {
    await module.close();
  });
});
