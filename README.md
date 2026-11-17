# Documentación
## TODO:arreglar Error al reiniciar
al momento por como funciona el mock crea los datos,
pero luego los intenta crear de nuevo lo que hace que el programa se caiga apesar de que este en un trycatch

osea que se tiene que ir a los servicios y comentar la funcion "initialize"
la forma correcta de esto seria hacer que corra un .sql al inicializarce pero no se me da la gana hacer esto -GB

## 1-Diagrama de arquitectura
```text
                       AWS (Nube)
+----------------------------------------------------+       Post-Confirmation Trigger
|                    AWS Cognito                     | --------------------------------------> +-------------------------------------+
|  - User Pool, App Client público, Grupos, Scopes   |                                         | Lambda Trigger (Post-Confirmation)  |
|                                                    |                                         |           "default-gamer"           |
|  - Grupo: "jugadores"                              | <-------------------------------------- | -Agrega usuario al grupo "jugadores"|
+----------------------------------------------------+       AdminAddUserToGroup API           +-------------------------------------+
     ^                                   |
     | Login /                           | JWKS (.well-known/jwks.json)
     | Auth Token                        v
+-----------------------------------------------------------------------------------------------------------------------------------+
| AMBIENTE LOCAL                                                                                                                    |
|                                                                                                                                   |
|  +----------------------------------------------------+                                                                           |
|  | VidalStore - Angular (Amplify / localhost:4200)    |                                                                           |
|  | - Guard de Ruta + Interceptor HTTP                 |                                                                           |
|  +----------------------------------------------------+                                                                           |
|                           |                                                                                                       |
|                           | Authorization: Bearer <access_token>                                                                  |
|                           v                                                                                                       |
|  +----------------------------------------------------+                                                                           |
|  | Gateway - NestJS (localhost:8080)                  | <--- Valida el token contra el JWKS de Cognito                            |
|  | - Rutas, CORS y validación centralizada            |                                                                           |
|  +----------------------------------------------------+                                                                           |
|                           |                                                                                                       |
|                           | Forward Request                                                                                       |
|                           v                                                                                                       |
|  +----------------------------------------------------+                                                                           |
|  | Layer BFF (Backend For Frontend)                   |                                                                           |
|  | - Orquestación de peticiones y formateo para UI    |                                                                           |
|  +----------------------------------------------------+                                                                           |
|                           |                                                                                                       |
|                           | Service Request                                                                                       |
|                           v                                                                                                       |
|  +----------------------------------------------------+                                                                           |
|  | Microservicio de Catálogo y Biblioteca             |                                                                           |
|  | - Vuelve a validar token                           |                                                                           |
|  | - Datos de guradan en memoria (Dictionary)         |                                                                           |
|  +----------------------------------------------------+                                                                           |
+-----------------------------------------------------------------------------------------------------------------------------------+
```

## 2-Script de ejecución bash
```text
#/bin/bash
mkdir repos
cd repos
git clone https://github.com/gebustoc/VidalStoreBff/
git clone https://github.com/gebustoc/VidalStoreGateway
git clone https://github.com/gebustoc/VidalStoreBack
git clone https://github.com/gebustoc/VidalStoreFront

cp ../.env VidalStoreBff/
cp ../.env VidalStoreGateway/
cp ../.env VidalStoreBack/
cp ../.env VidalStoreFront/

cd VidalStoreBack
mkdir mocks
npm install
node src/app.js &

cd ../VidalStoreBff
npm install
npm run start dev &

cd ../VidalStoreGateway
pnpm install
pnpm run start dev &

cd ../VidalStoreFront
npm install
npm run start
```
```
