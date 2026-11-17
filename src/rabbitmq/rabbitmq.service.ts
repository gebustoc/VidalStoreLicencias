import {
  Injectable,
  Logger,
  OnApplicationShutdown,
  OnModuleInit,
} from '@nestjs/common';
import amqp, { type Channel, type ChannelModel } from 'amqplib';
import { declararTopologia, EXCHANGES } from '../messaging/topology.js';

@Injectable()
export class RabbitMqService implements OnModuleInit, OnApplicationShutdown {
  private readonly logger = new Logger(RabbitMqService.name);
  private connection?: ChannelModel;
  private channel?: Channel;

  async onModuleInit(): Promise<void> {
    const url = process.env.RABBITMQ_URL ?? 'amqp://localhost:5672';

    this.connection = await amqp.connect(url);
    const connection = this.connection;
    this.channel = await connection.createChannel();
    await declararTopologia(this.channel);

    this.logger.log('RabbitMQ connected and topology declared');
  }

  async publish(
    routingKey: string,
    payload: unknown,
    exchange: string = EXCHANGES.eventos.nombre,
  ): Promise<void> {
    if (!this.channel) {
      throw new Error('RabbitMQ is not initialized');
    }

    const published = this.channel.publish(
      exchange,
      routingKey,
      Buffer.from(JSON.stringify(payload)),
      {
        contentType: 'application/json',
        deliveryMode: 2,
      },
    );

    if (!published) {
      this.logger.warn(`RabbitMQ reported backpressure for ${routingKey}`);
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await this.channel?.close();
    await this.connection?.close();
  }
}
