import { Module } from '@nestjs/common';
import { createObserveModule } from '@nestjs/observe';
import { AuthService } from '../service/auth.service.js';
import { Deleter } from '../model/Deleter.js';
import { Game } from '../model/Game.js';
import { License } from '../model/License.js';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthController } from '../controllers/auth.controller.js';
import { MessagingModule } from '../messaging/messaging.module.js';

@Module({
  imports: [TypeOrmModule.forFeature([License,Game,Deleter]), MessagingModule],
  controllers: [AuthController],
  providers: [AuthService],
})
export class AuthModule {}
