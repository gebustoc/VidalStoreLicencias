import { NestFactory } from '@nestjs/core';
import { AppModule, ObserveInstrument } from './modules/app.module.js';
import { loadEnvFile } from 'process';


async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    instrument: ObserveInstrument,
  });
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
