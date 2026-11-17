import { Injectable } from '@nestjs/common';
import { Game } from '../model/Game.js';
import { readFile } from 'fs/promises';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { RabbitMqService } from '../rabbitmq/rabbitmq.service.js';
import { KafkaService } from '../kafka/kafka.service.js';
import { EXCHANGES, ROUTING_KEYS } from '../messaging/topology.js';

@Injectable()
export class GameService {
  constructor(
    @InjectRepository(Game) private gameRepository: Repository<Game>,
    private readonly rabbitMqService: RabbitMqService,
    private readonly kafkaService: KafkaService,
  ) {
    this.Initialize()
  }

async Initialize() {
  try {
    let results: Array<Partial<Game>> = [];
    console.log(process.env.GAME_CATALOG_SOURCE)

    if (process.env.GAME_CATALOG_SOURCE === 'mock') {
      // type safety removed becuase it was not allowing the JSON file to be parsed as games
      const mockFile = process.env.GAME_MOCK_FILE ?? '/app/mocks/games.json';
      const data = JSON.parse(await readFile(mockFile, 'utf8'));// as {results?: Array<Partial<Game>>;};
      results = data ?? [];
      console.log(`[GameService] ${results.length} juegos cargados desde mock.`);

    } else {
      const response = await fetch(`https://api.rawg.io/api/games?key=${process.env.RAWG_KEY}&page_size=80`,);

      if (!response.ok) {
        console.warn(`[GameService] RAWG API respondió con status ${response.status}, omitiendo carga inicial de juegos.`);
        return;
      }

      const data = await response.json() as { results?: Array<Partial<Game>> };
      results = data.results ?? [];
    }

    if (!Array.isArray(results)) {
      console.warn('[GameService] Catálogo inválido, omitiendo carga inicial de juegos.');
      return;
    }

    for (const game of results) {
      if (!game.slug || !game.name) {
        console.warn('[GameService] Juego inválido en el catálogo, omitiendo registro.');
        continue;
      }

      await this.gameRepository
        .createQueryBuilder()
        .insert()
        .into(Game)
        .values({
          ...game,
          lowercasename: game.name.toLowerCase(),
        })
        .orIgnore()
        .execute();
    }
    if (process.env.GAME_CATALOG_SOURCE !== 'mock') {
      console.log(`[GameService] ${results.length} juegos cargados desde RAWG.`);
    }
  } catch (error) {
    console.warn('[GameService] No se pudo contactar la API de RAWG:', (error as Error).message);
    console.warn('[GameService] El backend continúa sin juegos precargados.');
  }
}

  async getGames(): Promise<Array<Game>>{
    return this.gameRepository.find();
  }

  async getGame(id: number): Promise<Game|null>{
    return this.gameRepository.findOneBy({ id })
  }

  async findGames(name: string) :Promise<Array<Game>>{
    return this.gameRepository.findBy({lowercasename:name})
  }

  async addGame(game: Game) {
    game.lowercasename = game.name.toLowerCase()
    //const savedGame = await this.gameRepository.save(game)
    await this.rabbitMqService.publish(
      ROUTING_KEYS.juegoPublicado,
      game,
      EXCHANGES.eventos.nombre,
    )

    return game
  }

  async writeGame(id: number, game: Game) {
    let storedGame: Game = (await this.getGame(id))!

    storedGame.slug = game.slug ?? storedGame.slug
    storedGame.name = game.name ?? storedGame.name
    storedGame.lowercasename = storedGame.name.toLowerCase()
    storedGame.released = game.released ?? storedGame.released
    storedGame.background_image = game.background_image ?? storedGame.background_image
    storedGame.saturated_color = game.saturated_color ?? storedGame.saturated_color
    storedGame.dominant_color = game.dominant_color ?? storedGame.dominant_color
    //const savedGame = await this.gameRepository.save(storedGame)
    await this.rabbitMqService.publish(ROUTING_KEYS.juegoPublicado,storedGame,EXCHANGES.eventos.nombre)
    //return savedGame
  }
}
