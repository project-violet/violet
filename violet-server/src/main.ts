import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupSwagger } from './common/utils/swagger';
import { logger } from './common/utils/logger';
import * as cookies from 'cookie-parser';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { logger: logger });

  app.setGlobalPrefix('api/v2');
  app.useGlobalPipes(new ValidationPipe());

  app.use(cookies());

  setupSwagger(app);

  await app.listen(3000);
}
bootstrap();
