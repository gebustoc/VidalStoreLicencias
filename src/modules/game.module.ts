import { Module } from '@nestjs/common';
import { createObserveModule } from '@nestjs/observe';
import { GameController } from '../controllers/game.controller.js';
import { GameService } from '../service/game.service.js';
import { Game } from '../model/Game.js';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MessagingModule } from '../messaging/messaging.module.js';


@Module({
  imports: [TypeOrmModule.forFeature([Game]), MessagingModule],
  controllers: [GameController],
  providers: [GameService],
})
export class GameModule {}
