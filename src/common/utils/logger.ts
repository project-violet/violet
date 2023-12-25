import { WinstonModule } from 'nest-winston';

const { format, transports } = require('winston');
const { combine, timestamp, printf, json, splat, prettyPrint } = format;

require('winston-daily-rotate-file');

const myFormat = printf(({ level, message, label, timestamp }) => {
  return `${timestamp} - ${level}: ${JSON.stringify(message, null, 2)}`;
});

const transport = new transports.DailyRotateFile({
  filename: './log/%DATE%.log',
  datePattern: 'YYYY-MM-DD',
});

export const logger = WinstonModule.createLogger({
  format: combine(timestamp(), json(), splat(), prettyPrint(), myFormat),
  transports: [transport],
});
