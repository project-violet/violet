import {
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { ViewService } from './view.service';
import {
  ApiCreatedResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { ViewGetRequestDto, ViewGetResponseDto } from './dtos/view-get.dto';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { ViewPostRequestDto } from './dtos/view-post.dto';
import { User } from 'src/user/entity/user.entity';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { AccessTokenGuard } from 'src/auth/guards/access-token.guard';

@ApiTags('view')
@Controller('view')
export class ViewController {
  constructor(private readonly viewService: ViewService) {}

  @Get()
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Get article read view' })
  @ApiCreatedResponse({
    description: 'View Result (Article, Count)',
    type: ViewGetResponseDto,
  })
  // @UseGuards(HmacAuthGuard)
  async get(@Query() dto: ViewGetRequestDto): Promise<ViewGetResponseDto> {
    return this.viewService.getView(dto);
  }

  @Post()
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Post article read data' })
  @UseGuards(HmacAuthGuard)
  post(@Query() dto: ViewPostRequestDto) {
    this.viewService.post(dto);
  }

  @Post('/logined')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Post article read data' })
  @UseGuards(HmacAuthGuard)
  @UseGuards(AccessTokenGuard)
  async postLogined(
    @CurrentUser() currentUser: User,
    @Query() dto: ViewPostRequestDto,
  ) {
    this.viewService.postLogined(currentUser, dto);
  }
}
