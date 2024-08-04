import { Module } from '@nestjs/common';
import { MySQLConfigService } from './config.service';

@Module({
  providers: [MySQLConfigService],
})
export class MySQLConfigModule {}
