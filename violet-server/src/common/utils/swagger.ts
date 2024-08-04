import { INestApplication } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

/**
 * Swagger 세팅
 *
 * @param {INestApplication} app
 */
export function setupSwagger(app: INestApplication): void {
  const options = new DocumentBuilder()
    .setTitle('Violet Server API Docs')
    .setDescription('Violet Server API description')
    .setVersion('1.0.0')
    .setBasePath('api/v2')
    .build();

  const document = SwaggerModule.createDocument(app, options);
  SwaggerModule.setup('api/v2/docs', app, document);
}
