import {
  Controller,
  Get,
  Query,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { RankService } from './rank.service';
import { ApiOperation, ApiResponse } from '@nestjs/swagger';
import { RankRequestDto, RankResponseDto } from './dtos/rank-get.dto';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';

@Controller('rank')
export class RankController {
  constructor(private readonly rankService: RankService) {}

  @Get()
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Get article read rank' })
  @ApiResponse({
    type: RankResponseDto,
  })
  // @UseGuards(HmacAuthGuard)
  async get(@Query() dto: RankRequestDto) {
    return this.rankService.getRank(dto);
  }
}
