import {
  Injectable,
  Logger,
  OnApplicationShutdown,
  Inject
} from '@nestjs/common';

import { PRODUCTOR, type ProductorKafka } from './productor.provider.js';
import { aMensaje } from './a-message.js';
import { randomUUID } from 'crypto';
import { plainToInstance } from 'class-transformer';
import { EventoDto, TipoEvento } from './event.dto.js';
import { validate } from 'class-validator';

@Injectable()
export class KafkaService implements OnApplicationShutdown {
  private readonly logger = new Logger(KafkaService.name);

  // kafka on the beat
  constructor(@Inject(PRODUCTOR) private readonly producer: ProductorKafka) {}


  async publicar(
    tipo: TipoEvento,
    juegoId: number,
    usuarioSub: string,
    datos: Record<string, unknown>,
  ): Promise<void> {
    const evento = plainToInstance(EventoDto, {
      eventoId: randomUUID(),
      tipo,
      version: 1,
      emitidoEn: new Date().toISOString(),
      juegoId: String(juegoId),
      usuarioSub,
      datos,
    });

    try {
      const errores = await validate(evento, { whitelist: true, forbidNonWhitelisted: true });
      if (errores.length > 0) {
        throw new Error(`el evento no cumple el DTO: ${errores.map((e) => e.toString(false, true)).join(' | ')}`);
      }
      // en el servicio, despues de guardar:
      const resultado = await this.producer.send({ messages: [aMensaje(evento)] });
      const o = resultado.offsets?.[0];
      this.logger.log(`kafka: ${tipo} evento ${evento.eventoId} en ${o?.topic}[${o?.partition}] offset ${o?.offset}`);
    } catch (error) {
      this.logger.error(`kafka: no se pudo publicar ${tipo} evento ${evento.eventoId}: ${detalle(error)}`);
    }
  }

  async onApplicationShutdown(): Promise<void> {
    this.logger.log('trying to disconnect Kafka producer');
    await this.producer.close().catch(()=>undefined)
  }
}



// El cliente anida los errores (`errors`): el de arriba solo dice "Producing messages failed" y el motivo real
// esta en las hojas, repetido una vez por intento. Se juntan sin repetir.
function detalle(error: unknown): string {
  type Anidado = { message?: string; errors?: Anidado[] };
  const motivos = new Set<string>();
  const recorrer = (e: Anidado): void => {
    if (e.errors?.length) e.errors.forEach(recorrer);
    else motivos.add(e.message ?? String(e));
  };
  recorrer(error as Anidado);
  return `${(error as Anidado).message ?? 'error'} (${[...motivos].join('; ')})`;
}
