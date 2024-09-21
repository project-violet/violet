import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiCreatedResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRegisterDTO } from './dtos/user-register.dto';
import { UserService } from './user.service';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { AccessTokenGuard } from 'src/auth/guards/access-token.guard';
import { ListDiscordUserAppIdsResponseDto } from './dtos/list-discord.dto';
import { CommonResponseDto } from 'src/common/dtos/common.dto';
import { plainToClass } from 'class-transformer';
import { User } from './entity/user.entity';

@ApiTags('user')
@Controller('user')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get()
  @ApiOperation({ summary: 'Get current user information' })
  @ApiCreatedResponse({ description: 'User Information', type: User })
  @UseGuards(AccessTokenGuard)
  getCurrentUser(@CurrentUser() currentUser: User): User {
    return plainToClass(User, currentUser);
  }

  @Post('/')
  @ApiOperation({ summary: 'Register User' })
  @ApiCreatedResponse({ description: '' })
  @UseGuards(HmacAuthGuard)
  async registerUser(@Body() dto: UserRegisterDTO): Promise<CommonResponseDto> {
    return await this.userService.registerUser(dto);
  }

  @Get('discord')
  @ApiOperation({ summary: 'Get userAppIds registered by discord id' })
  @ApiCreatedResponse({
    description: '',
    type: ListDiscordUserAppIdsResponseDto,
  })
  @UseGuards(AccessTokenGuard)
  async listDiscordUserAppIds(
    @CurrentUser('discordId') discordId?: string,
  ): Promise<ListDiscordUserAppIdsResponseDto> {
    return await this.userService.listDiscordUserAppIds(discordId);
  }
}
