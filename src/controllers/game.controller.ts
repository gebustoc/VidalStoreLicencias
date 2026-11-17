import { Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { Game } from '../model/Game.js';
import { GameService } from '../service/game.service.js';

@Controller()
export class GameController {
  constructor(private readonly gameService: GameService) {}

  @Get("/v1/catalogo")
  async getGames() : Promise<Array<Game>>{
    return this.gameService.getGames();
  }

  @Get("/v1/catalogo/:id")
  async getGame(@Param("id") id : number) : Promise<Game|null>{
    return this.gameService.getGame(id)
  }

  @Put("/v1/catalogo/:id")
  async putGame(@Body() body:Game,@Param("id") id : number ){
    return this.gameService.writeGame(id,body);
  }

  @Post("/v1/catalogo")
  async addGame(@Body() body:Game){
    return this.gameService.addGame(body);
  }

}
