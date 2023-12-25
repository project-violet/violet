import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupSwagger } from './common/utils/swagger';
import { logger } from './common/utils/logger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix('api/v1');
  app.useLogger(logger);

  setupSwagger(app);

  await app.listen(3000);
}
bootstrap();
