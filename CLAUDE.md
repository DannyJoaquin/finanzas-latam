# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentación existente — leer antes de explorar el repo

Este repo ya tiene dos documentos de mapeo generados por análisis exhaustivo. **Consúltalos antes de recorrer el código desde cero**:

- **[`CODEBASE_MAP.md`](./CODEBASE_MAP.md)** — responde "¿qué hace cada archivo?": estructura de carpetas, tabla de módulos/features, mapa de archivos, flujos de negocio completos, todos los endpoints de API, entidades y relaciones, migraciones, cron jobs, índice de búsqueda por funcionalidad.
- **[`ARCHITECTURE_KNOWLEDGE.md`](./ARCHITECTURE_KNOWLEDGE.md)** — responde "¿qué se rompe si lo cambio?": grafo de dependencias entre módulos, acoplamientos implícitos vía entidades TypeORM compartidas, sequence diagrams de los flujos críticos, call chains para tareas comunes, deuda técnica identificada, áreas de alto riesgo, y la sección de **Despliegue y Operación** (Render/Cloudflare Pages/Neon/Upstash).

Actualiza ambos documentos cuando el cambio lo amerite (nuevo módulo, nueva relación de entidades, deuda técnica resuelta/introducida) — no en cada commit menor.

## Qué es Zentri

App de finanzas personales (antes "FinanzasLATAM") orientada a Centroamérica/Honduras (moneda default HNL, ciclos de pago quincenales). Monorepo con dos proyectos independientes que se comunican vía REST JSON bajo el prefijo `api/v1`:

- **`backend/`** — NestJS 11 + TypeScript + TypeORM/PostgreSQL, modular por dominio de negocio.
- **`mobile/`** — Flutter/Dart (Riverpod + go_router + Dio), organizado por features.

## Comandos

### Backend (`backend/`)

```bash
npm run start:dev          # servidor con watch/hot-reload
npm run build               # nest build
npm run lint                 # eslint --fix sobre src/apps/libs/test
npm run format               # prettier --write

npm run test                 # jest (unit)
npm run test:watch
npm run test:cov
npm run test:e2e             # jest -c test/jest-e2e.json
# correr un solo spec:
npx jest src/modules/expenses/expenses.service.spec.ts

npm run migration:generate   # typeorm-ts-node-commonjs migration:generate -d data-source.ts
npm run migration:run
npm run migration:revert
npm run seed                 # categorías + datos demo (run-seeds.ts)
```

Local con Docker (api + postgres + redis):

```bash
docker-compose up
```

### Mobile (`mobile/`)

```bash
flutter pub get
flutter run                          # requiere dispositivo/emulador o -d chrome
flutter test                         # correr toda la suite
flutter test test/money_input_formatter_test.dart   # un solo archivo
flutter analyze                      # lint (flutter_lints)
flutter build web --release          # build de la PWA (usa CanvasKit en CI)
dart run build_runner build --delete-conflicting-outputs   # freezed/json_serializable/riverpod_generator/go_router_builder
```

`build_runner` es necesario tras tocar cualquier archivo con `@freezed`, `part '*.g.dart'`, o rutas anotadas con `@TypedGoRoute`.

## Arquitectura — puntos que no son obvios leyendo un solo archivo

Ver [`ARCHITECTURE_KNOWLEDGE.md`](./ARCHITECTURE_KNOWLEDGE.md) para el detalle completo con diagramas. Resumen de lo más importante para no romper cosas:

- **`User` y `Expense` tienen el mayor "blast radius"**: casi todos los módulos backend importan su `.entity.ts` directamente en vez de pasar por el service del módulo dueño (acoplamiento implícito, no visible en `imports: []` de ningún `.module.ts`). Antes de renombrar/eliminar una columna, grepea el nombre de la entidad en todo `backend/src`.
- **Contrato de respuesta global `{data: ...}`**: `TransformInterceptor` envuelve toda respuesta exitosa; `dio_client.dart` en mobile la desempaqueta automáticamente. Cambiarlo rompe el mobile completo de una vez — no hay versionado de API. Si hace falta cambiar el formato, hacerlo vía un prefijo nuevo (`api/v2`) en paralelo.
- **Notificaciones sin despachador central**: 8 puntos distintos (6 cron jobs + `insights-generator.service.ts` + `shared-expenses.service.ts`/`settlements.service.ts`) consultan `UserNotificationPreferences` y llaman `PushNotificationService.send` de forma independiente. Agregar un canal o regla global implica tocar los 8, no 1.
- **Motor de `rules` desconectado**: `RulesEvaluatorService.evaluateOnExpense` existe y funciona pero nada lo invoca — `ExpensesService.create` no lo llama. El CRUD de reglas es 100% funcional en la app pero las reglas nunca se evalúan.
- **`shared-groups/`** es el módulo backend más aislado (nadie lo importa) pero de mayor riesgo de negocio (dinero real entre usuarios, algoritmo de neteo en `BalancesService.getGroupBalances` sin tests). `rejectExpense` tiene un bug conocido: revierte el estado a `PENDING` en vez de un estado `REJECTED` explícito.
- **Migraciones con `ALTER TYPE ... ADD VALUE`** (enums Postgres) son irreversibles en producción — confirmar el nombre del valor antes de migrar.
- **Mobile**: `expenses_provider.dart` es el archivo más reusado (exporta `categoriesProvider`, modelos, `suggestCategory`) — lo consumen `home`, `budgets`, `credit_cards`, `analytics/simulator`. `achievements_screen.dart` no tiene modelo/provider propio: depende 100% de `home/providers/dashboard_provider.dart`, dependencia invisible desde fuera de `home/`.
- **`money_input_formatter.dart`** (`mobile/lib/core/formatters/`) es el `TextInputFormatter` compartido por **todos** los formularios de montos (gastos, ingresos, presupuestos, metas, tarjetas, cash, gastos compartidos, calculadora de préstamos). Un fix ahí aplica a toda la app de una vez — y un bug ahí también.

## Despliegue

Resumen operativo — detalle completo (variables de entorno, flujo de CI, verificación post-deploy) en [`ARCHITECTURE_KNOWLEDGE.md` → Despliegue y Operación](./ARCHITECTURE_KNOWLEDGE.md#despliegue-y-operacion).

| Componente | Servicio |
|---|---|
| Backend NestJS | Render (`https://api.zentri.tech/api/v1`) |
| Frontend Flutter Web/PWA | Cloudflare Pages (`https://app.zentri.tech`) |
| PostgreSQL | Neon |
| Redis | Upstash |
| Push notifications | Firebase Cloud Messaging |

Push a `master` dispara GitHub Actions (tests + build + deploy PWA a Cloudflare Pages) y Render (build Docker + migraciones + seed de categorías + arranque). Las migraciones corren automáticamente antes de levantar el backend; nunca se debe recrear Neon para un cambio normal de esquema.
