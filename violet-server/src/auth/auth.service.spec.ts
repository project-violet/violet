import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { ConfigModule } from '@nestjs/config';
import { HmacAuthGuard } from './guards/hmac.guard';
import { JwtModule } from '@nestjs/jwt';
import { UserRepository } from 'src/user/user.repository';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserModule } from 'src/user/user.module';
import { MySQLConfigModule } from 'src/config/config.module';
import { MySQLConfigService } from 'src/config/config.service';
import { envValidationSchema } from 'src/app.module';

describe('AuthService', () => {
  let service: AuthService;
  let controller: AuthController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [UserRepository, AuthService],
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          envFilePath: '.test.env',
          validationSchema: envValidationSchema,
        }),
        JwtModule.register({}),
        UserModule,
        TypeOrmModule.forRootAsync({
          imports: [MySQLConfigModule],
          useClass: MySQLConfigService,
          inject: [MySQLConfigService],
        }),
      ],
      controllers: [AuthController],
    })
      .overrideGuard(HmacAuthGuard)
      .useValue({ canActivate: jest.fn(() => true) })
      .compile();

    service = module.get<AuthService>(AuthService);
    controller = module.get<AuthController>(AuthController);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
    expect(controller).toBeDefined();
  });
});
