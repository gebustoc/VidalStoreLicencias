import { Injectable } from '@nestjs/common';
import { Game } from '../model/Game.js';
import {writeFileSync } from 'fs';
import { randomUUID, UUID } from 'crypto';
import { License } from '../model/License.js';
import { GameService } from './game.service.js';
import { Deleter } from '../model/Deleter.js';
import { Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { RabbitMqService } from '../rabbitmq/rabbitmq.service.js';
import { KafkaService } from '../kafka/kafka.service.js';
import { EXCHANGES, ROUTING_KEYS } from '../messaging/topology.js';
import { getMaxListeners } from 'stream';

@Injectable()
export class AuthService {
    Auth :Map<number,License> = new Map();
    Deleters :Map<number,any> = new Map();

    deleterID= 0

  constructor(
    @InjectRepository(License) private authRepository: Repository<License>,
    @InjectRepository(Game) private gameRepository: Repository<Game>,
    @InjectRepository(Deleter) private deleterRepository: Repository<Deleter>,
    private readonly rabbitMqService: RabbitMqService,
    private readonly kafkaService: KafkaService,
  ) {
        this.Initialize()
    }



    async Initialize(){
      const maxWait = 60000; // 60 segundos máximo
      const start = Date.now();
      while (true) {
        await new Promise((resolve) => setTimeout(resolve, 250));
        const gamecheck = await this.gameRepository.find()
        if (gamecheck.length > 0) break
        if (Date.now() - start > maxWait) {
          console.warn('[AuthService] Timeout esperando juegos. El servicio continúa sin licencias iniciales.');
          return;
        }
      }

        const games :Array<Game> = await this.gameRepository.find()
        for (let index = 0; index < games.length * 2; index++) {
          const rndIDX :number= Math.floor(Math.random()*(games.length-1));
          const game :Game= games[rndIDX]
          const license :License= new License(randomUUID(),undefined,game);
          this.authRepository.save(license)
        }
    }

    async getLibrary(uid: string): Promise<Array<Game>>{
        // Query the database for all licenses belonging to this user
        const licenses = await this.authRepository.find({
            where: { uid },
            relations: { game: true }
        });

        // Extract and return the games from the licenses
        return licenses
            .filter(license => license.game != undefined)
            .map(license => license.game);
    }

    async buyGame(sub: string, gid: number) {
      const game = await this.gameRepository.findOneByOrFail({id:gid});

      await this.rabbitMqService.publish(
        ROUTING_KEYS.compraRealizada,
        { gameID: gid,uid: sub },
        EXCHANGES.eventos.nombre,
      )

      await this.kafkaService.publicar(
        'compra.realizada',
        gid,
        String(gid),
        {
          // i have programmed myself into a corner (have no ID)
          // but wasn't rabbit meant to write to tables?
          ventaId: "PLACEHOLDER",
          timestamp: new Date().toISOString(),
        },
      )


    }

    async getLicenses() :Promise<Array<License>> {return this.authRepository.find()}

    // solution done, something like this also needs to be
    // done when running licencia.eliminar
    async removeLicense(lid:number,uid:string){
      const licenseToKill: License = (await this.authRepository.findOneBy({ id: lid }))!

      await this.kafkaService.publicar(
        'licencia.revocada',
        licenseToKill.game.id,
        String(licenseToKill.game.id),
        {
          // i have programmed myself into a corner (have no ID)
          // but wasn't rabbit meant to write to tables?
          quienBorro: uid,
        },
      )

      await this.rabbitMqService.publish(
        ROUTING_KEYS.licensiaRevocada,
        { licenseID: licenseToKill.id,owner: licenseToKill.uid, whodeleted:uid } ,
        EXCHANGES.eventos.nombre,
      )


    }

    async getDeleters() :Promise<Array<Deleter>> {return this.deleterRepository.find()}




}
