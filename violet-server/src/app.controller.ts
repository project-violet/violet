import { Controller, Get, UseGuards } from '@nestjs/common';
import { AppService } from './app.service';
import { HmacAuthGuard } from './auth/guards/hmac.guard';
import { ApiTags } from '@nestjs/swagger';

@ApiTags('app')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('/hmac')
  @UseGuards(HmacAuthGuard)
  getHmac(): string {
    return 'success';
  }
}
