import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiCreatedResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRegisterDTO } from './dtos/user-register.dto';
import { UserService } from './user.service';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { AccessTokenGuard } from 'src/auth/guards/access-token.guard';
import { ListDiscordUserAppIdsResponseDto } from './dtos/list-discord.dto';

@ApiTags('user')
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
