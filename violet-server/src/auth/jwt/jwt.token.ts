import { ApiProperty } from '@nestjs/swagger';

export class Tokens {
  @ApiProperty({ description: 'accessToken' })
  accessToken: string;

  @ApiProperty({ description: 'refreshToken' })
  refreshToken: string;
}
