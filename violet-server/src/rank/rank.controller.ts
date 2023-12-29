import {
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { RankService } from './rank.service';
import { ApiOperation, ApiResponse } from '@nestjs/swagger';
import { RankGetRequestDto, RankGetResponseDto } from './dtos/rank-get.dto';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { RankPostRequestDto } from './dtos/rank-post.dto';
import { User } from 'src/user/entity/user.entity';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { AccessTokenGuard } from 'src/auth/guards/access-token.guard';

@Controller('rank')
export class RankController {
  constructor(private readonly rankService: RankService) {}

  @Get()
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Get article read rank' })
  @ApiResponse({
    type: RankGetResponseDto,
  })
  @UseGuards(HmacAuthGuard)
  async get(@Query() dto: RankGetRequestDto) {
    return this.rankService.getRank(dto);
  }

  @Post()
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Post article read data' })
  @UseGuards(HmacAuthGuard)
  post(@Query() dto: RankPostRequestDto) {
    this.rankService.post(dto);
  }

  @Post('/logined')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Post article read data' })
  @UseGuards(HmacAuthGuard)
  @UseGuards(AccessTokenGuard)
  async postLogined(
    @CurrentUser() currentUser: User,
    @Query() dto: RankPostRequestDto,
  ) {
    this.rankService.postLogined(currentUser, dto);
  }
}
