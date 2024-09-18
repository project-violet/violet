import { S3Client } from '@aws-sdk/client-s3';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createPresignedPost, PresignedPost } from '@aws-sdk/s3-presigned-post';

@Injectable()
export class AWSService {
  s3: S3Client;

  constructor(private configService: ConfigService) {
    this.s3 = new S3Client({
      region: this.configService.get('DEFAULT_REGION_NAME'),
      credentials: {
        accessKeyId: this.configService.get('AWS_ACCESS_KEY'),
        secretAccessKey: this.configService.get('AWS_SECRET_ACCESS_KEY'),
      },
    });
  }

  async makePresignedPost(
    bucket: string,
    filename: string,
    {
      maxSize = 10 * 1024 * 1024,
      contentType = 'text/json',
    }: {
      maxSize?: number;
      contentType?: string;
    },
  ): Promise<PresignedPost> {
    return await createPresignedPost(this.s3, {
      Bucket: bucket,
      Key: filename,
      Conditions: [
        ['content-length-range', 0, maxSize],
        ['eq', '$acl', 'public-read'],
      ],
      Expires: 120,
      Fields: {
        acl: 'public-read',
        'Content-Type': contentType,
      },
    });
  }
}
