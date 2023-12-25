import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiCreatedResponse, ApiOperation } from '@nestjs/swagger';
import { UserRegisterDTO } from './dtos/user-register.dto';
import { UserService } from './user.service';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';

@Controller('user')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post('/')
  @ApiOperation({ summary: 'Register User' })
  @ApiCreatedResponse({ description: '' })
  @UseGuards(HmacAuthGuard)
  async registerUser(
    @Body() dto: UserRegisterDTO,
  ): Promise<{ ok: boolean; error?: string }> {
    return await this.userService.registerUser(dto);
  }
}
