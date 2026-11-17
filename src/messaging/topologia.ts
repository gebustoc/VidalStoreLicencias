import { Channel } from 'amqplib';

// Los tres exchanges. El tipo va al lado del nombre porque declararlo con otro tipo es un error.
export const EXCHANGES = {
  eventos: { nombre: 'vidalstore.eventos', tipo: 'topic' },
  comandos: { nombre: 'vidalstore.comandos', tipo: 'direct' },
} as const;

export const ROUTING_KEYS = {
  correoEnviar: 'correo.enviar',
  licenciaComprar: "licencia.comprar",
  licenciaEliminar: "licencia.eliminar",
  juegoCrear: "juego.crear",
  juegoBorrar: "juego.borrar",
  juegoActualizar: "juego.actualizar",
} as const;


export async function declararTopologia(canal: Channel): Promise<void> {
  for (const exchange of Object.values(EXCHANGES)) {
    await canal.assertExchange(exchange.nombre, exchange.tipo, { durable: true });
  }
}
