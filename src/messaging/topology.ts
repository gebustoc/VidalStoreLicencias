import type { Channel } from 'amqplib';

export const EXCHANGES = {
  eventos: { nombre: 'vidalstore.eventos', tipo: 'topic' },
  comandos: { nombre: 'vidalstore.comandos', tipo: 'direct' },
} as const;

export const ROUTING_KEYS = {
  compraRealizada: "compra.realizada",
  licensiaRevocada:"licencia.revocada",
  juegoPublicado:"juego.publicado",
  correoEnviar:"correo.enviar"
} as const;


export async function declararTopologia(canal: Channel): Promise<void> {
  for (const exchange of Object.values(EXCHANGES)) {
    await canal.assertExchange(exchange.nombre, exchange.tipo, {
      durable: true,
    });
  }
}
