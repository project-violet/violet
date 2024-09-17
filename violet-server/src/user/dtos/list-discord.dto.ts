import { ApiProperty } from '@nestjs/swagger';
import { IsString } from 'class-validator';

export class ListDiscordUserAppIdsResponseDto {
  @IsString()
  @ApiProperty({
    description: 'User App Ids',
    required: true,
  })
  userAppIds: string[];
}
