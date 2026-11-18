FROM node:24 AS builder
WORKDIR /data
COPY *.json .
RUN npm install
COPY src/ ./src
RUN npm run build


FROM node:24-alpine AS runner

WORKDIR /app
COPY --from=builder /data/dist .
COPY --from=builder /data/node_modules ./node_modules
RUN mkdir -p mocks
EXPOSE 3000
CMD [ "node", "./main.js" ]
