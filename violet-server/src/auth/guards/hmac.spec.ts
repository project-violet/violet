import { ConfigModule, ConfigService } from '@nestjs/config';
import { HmacAuthGuard } from './hmac.guard';
import { Test, TestingModule } from '@nestjs/testing';
import { envValidationSchema } from 'src/app.module';
import { createMock } from '@golevelup/ts-jest';
import { BadRequestException, ExecutionContext } from '@nestjs/common';

describe('HmacAuthGuard', () => {
  let guard: HmacAuthGuard;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          envFilePath: '.test.env',
          validationSchema: envValidationSchema,
        }),
      ],
      providers: [HmacAuthGuard],
    }).compile();

    guard = module.get<HmacAuthGuard>(HmacAuthGuard);
  });

  it('should be defined', () => {
    expect(guard).toBeDefined();
  });

  function mockContext(token: string, valid: string) {
    return createMock<ExecutionContext>({
      switchToHttp: () => ({
        getRequest: () => ({
          headers: {
            'v-token': token,
            'v-valid': valid,
          },
        }),
      }),
    });
  }

  it('hmac success', () => {
    const token = new Date().getTime().toString();
    const context = mockContext(token, guard.buildHmac(token));
    expect(guard.canActivate(context)).toBeTruthy();
  });

  it('hmac fail timestamp invalid format', () => {
    const context = mockContext('abcd', 'edfg');
    expect(() => guard.canActivate(context)).toThrow(BadRequestException);
  });

  it('hmac fail timestamp diff less', () => {
    const token = (new Date().getTime() - 40000).toString();
    const context = mockContext(token, guard.buildHmac(token));
    expect(() => guard.canActivate(context)).toThrow(BadRequestException);
  });

  it('hmac fail timestamp diff greater', () => {
    const token = (new Date().getTime() + 40000).toString();
    const context = mockContext(token, guard.buildHmac(token));
    expect(() => guard.canActivate(context)).toThrow(BadRequestException);
  });
});
