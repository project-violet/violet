import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AWSService } from './aws.service';

@Module({
  imports: [ConfigModule],
  providers: [AWSService],
  controllers: [AWSService],
})
export class AWSModule {}
