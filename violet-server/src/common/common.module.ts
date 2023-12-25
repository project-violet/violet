import { Module } from '@nestjs/common';
import { Logger } from 'winston';

@Module({ providers: [Logger], exports: [Logger] })
export class CommonModule {}
