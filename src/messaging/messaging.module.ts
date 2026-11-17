import { Module } from '@nestjs/common';
import { RabbitMqService } from '../rabbitmq/rabbitmq.service.js';
import { KafkaService } from '../kafka/kafka.service.js';
import { productorProvider } from '../kafka/productor.provider.js';

@Module({
  providers: [RabbitMqService, productorProvider, KafkaService],
  exports: [RabbitMqService, productorProvider, KafkaService],
})
export class MessagingModule {}
