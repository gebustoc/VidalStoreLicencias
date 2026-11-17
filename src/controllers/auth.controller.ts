import { Body, Controller, Delete, Get, Header, Headers, Param, Post, Put } from '@nestjs/common';
import { AuthService } from '../service/auth.service.js';
import { Deleter } from '../model/Deleter.js';
import { Game } from '../model/Game.js';
import { License } from '../model/License.js';
import { Claims, verifyToken } from '../verification.js';

@Controller()
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Get("/v1/licencias/deleters")
  async getDeleters() : Promise<Array<Deleter>>{
    return await this.authService.getDeleters()
  }

  @Get("/v1/biblioteca")
  async getBiblioteca(@Headers('authorization') auth : string) : Promise<Game[]>{
    const claims :Claims = await verifyToken(auth)
    return await this.authService.getLibrary(claims.sub)
  }

  @Post("/v1/compras/:id")
  async buyGame(@Headers('authorization') auth : string, @Param("id") id : number){
    const claims :Claims = await verifyToken(auth)
    return this.authService.buyGame(claims.sub,id)
  }

  @Get("/v1/licencias")
  async getLicenses() : Promise<Array<License>> {
    return this.authService.getLicenses()
  }

  @Delete("/v1/licencias/:id")
  async removeLicense(@Headers('authorization') auth : string, @Param("id") id : number){
    const claims :Claims = await verifyToken(auth)
    return await this.authService.removeLicense(id,claims.sub)
  }




}
