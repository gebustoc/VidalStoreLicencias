import { BadRequestException, Body, Controller, Delete, ForbiddenException, Get, Header, Headers, Param, Post, Put } from '@nestjs/common';
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
    let claims :Claims 
    try{claims = await verifyToken(auth) }
    catch(error){throw new BadRequestException(`${error}`)}
    return await this.authService.getLibrary(claims.sub)
  }

  @Post("/v1/compras/:id")
  async buyGame(@Headers('authorization') auth : string, @Param("id") idText : string){
    let claims :Claims 
    let id :undefined|number= undefined;    

    try{claims = await verifyToken(auth) }
    catch(error){throw new BadRequestException(`${error}`)}
    try{id = Number.parseInt(idText)}
    catch(error){throw new BadRequestException(`id must be a valid integer:${error}`)}
    return this.authService.buyGame(claims.sub,id)


  }

  @Get("/v1/licencias")
  async getLicenses() : Promise<Array<License>> {
    return this.authService.getLicenses()
  }

  @Delete("/v1/licencias/:id")
  async removeLicense(@Headers('authorization') auth : string, @Param("id") idText : string){
    let claims :Claims 
    let id :undefined|number= undefined;    

    try{claims = await verifyToken(auth) }
    catch(error){throw new BadRequestException(`${error}`)}    
    
    try{id = Number.parseInt(idText)}
    catch(error){throw new BadRequestException(`id must be a valid integer:${error}`)}


    if (!(Number.isInteger(id)) ){throw new BadRequestException("id must be a valid integer")}


    return await this.authService.removeLicense(id,claims.sub)
  }




}
