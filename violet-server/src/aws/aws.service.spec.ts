import { Test, TestingModule } from '@nestjs/testing';
import { AWSService } from './aws.service';
import { envValidationSchema } from 'src/app.module';
import { ConfigModule } from '@nestjs/config';

describe('AWSService', () => {
  let service: AWSService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [AWSService],
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          envFilePath: '.test.env',
          validationSchema: envValidationSchema,
        }),
      ],
    }).compile();

    service = module.get<AWSService>(AWSService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
