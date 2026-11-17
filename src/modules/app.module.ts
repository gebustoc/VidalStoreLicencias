import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { createObserveModule } from '@nestjs/observe';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthController } from '../controllers/auth.controller.js';
import { GameController } from '../controllers/game.controller.js';
import { Deleter } from '../model/Deleter.js';
import { Game } from '../model/Game.js';
import { License } from '../model/License.js';
import { AuthService } from '../service/auth.service.js';
import { GameService } from '../service/game.service.js';
import { AuthModule } from './auth.module.js';
import { GameModule } from './game.module.js';
import { MessagingModule } from '../messaging/messaging.module.js';


export const { ObserveModule, ObserveInstrument } = createObserveModule();

@Module({
    imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST||'localhost',
      port: 5432,
      username: process.env.DB_USER||'root',
      password: process.env.DB_PASSWORD||'root',
      database: process.env.DB_NAME||'test',
      entities: [Deleter,Game,License],
      synchronize: true,
    }), GameModule, AuthModule, MessagingModule
  ],
})
export class AppModule {}
