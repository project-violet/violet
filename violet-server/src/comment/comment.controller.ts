import {
  Body,
  Controller,
  Get,
  Post,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { CommentService } from './comment.service';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { CommentPostDto } from './dtos/comment-post.dto';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { User } from 'src/user/entity/user.entity';
import { AccessTokenGuard } from 'src/auth/guards/access-token.guard';

@ApiTags('comment')
@Controller('comment')
export class CommentController {
  constructor(private readonly commentService: CommentService) {}

  @Get('/')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Get Comment' })
  @UseGuards(HmacAuthGuard)
  @UseGuards(AccessTokenGuard)
  async getComment(
    @CurrentUser() currentUser: User,
    @Body() dto: CommentPostDto,
  ): Promise<{ ok: boolean; error?: string }> {
    return await this.commentService.postComment(currentUser, dto);
  }

  @Post('/')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Post Comment' })
  @UseGuards(HmacAuthGuard)
  @UseGuards(AccessTokenGuard)
  async postComment(
    @CurrentUser() currentUser: User,
    @Body() dto: CommentPostDto,
  ): Promise<{ ok: boolean; error?: string }> {
    return await this.commentService.postComment(currentUser, dto);
  }
}
