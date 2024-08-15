import {
  Body,
  Controller,
  Post,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { CommentService } from './comment.service';
import { HmacAuthGuard } from 'src/auth/guards/hmac.guard';
import { CommentPostDto } from './dtos/comment-post.dto';
import { ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { User } from 'src/user/entity/user.entity';
import { AccessTokenGuard } from 'src/auth/guards/access-token.guard';

@Controller('comment')
export class CommentController {
  constructor(private readonly commentService: CommentService) {}

  @Post('/')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Post Comment' })
  @UseGuards(HmacAuthGuard)
  @UseGuards(AccessTokenGuard)
  async postComment(
    @CurrentUser() currentUser: User,
    @Body() dto: CommentPostDto,
  ) {
    this.commentService.postComment(currentUser, dto);
  }
}
