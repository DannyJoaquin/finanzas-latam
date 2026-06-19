# CODEBASE_MAP.md — Zentri (FinanzasLATAM)

> Mapa de conocimiento persistente del proyecto. Generado por análisis exhaustivo del código (backend NestJS + app móvil Flutter). Úsalo como referencia principal antes de recorrer el proyecto de nuevo; actualízalo cuando cambie la arquitectura, no en cada commit menor.

---

## Resumen General

**Propósito**: Zentri (nombre anterior: FinanzasLATAM) es una app de finanzas personales orientada a Centroamérica/Honduras (moneda default HNL, ciclos de pago quincenales). Permite registrar gastos/ingresos, presupuestos, metas de ahorro, cuentas de efectivo, tarjetas de crédito, generación automática de insights financieros (anomalías, proyecciones de flujo de caja, rachas, logros), reglas de automatización, y un módulo de **gastos compartidos en grupo** (tipo Splitwise) con liquidación de deudas.

**Tecnologías**:
- **Backend**: NestJS 11 + TypeScript, TypeORM + PostgreSQL 15, Redis (ioredis, vía `@nestjs-modules/ioredis`), Bull (colas, declarado pero sin uso visible), `@nestjs/schedule` (cron jobs), JWT (`@nestjs/jwt` + `passport-jwt`/`passport-local`), `bcrypt`, `google-auth-library` (login Google), `firebase-admin` (push FCM).
- **Mobile**: Flutter/Dart, `flutter_riverpod` (estado), `go_router` (rutas), `dio` (HTTP), `hive`/`hive_flutter` (storage no sensible), `flutter_secure_storage` (tokens), `firebase_messaging` + `flutter_local_notifications` (push), `fl_chart` (gráficos), `pdf`/`share_plus`/`path_provider` (exportación), `google_sign_in`.
- **Infra**: Docker Compose (api + postgres + redis).

**Arquitectura**: Monorepo con dos proyectos independientes que se comunican vía REST JSON (prefijo `api/v1`):
- `backend/` — API NestJS modular (un módulo de Nest por dominio de negocio), autenticación JWT global por defecto (`@Public()` para excepciones), respuesta envuelta en `{data: ...}` (vía `TransformInterceptor`), migraciones manuales de TypeORM (`synchronize: false` siempre).
- `mobile/` — App Flutter por *features* (cada feature: `models/`, `providers/`, `presentation/screens/`, a veces `repositories/`/`services/`), patrón dominante: modelo (`fromJson`) → provider Riverpod (`FutureProvider.autoDispose`, llama Dio directo) → pantalla `ConsumerWidget` (`ref.watch(...).when(...)`).
- 6 **cron jobs** en backend (`src/jobs/`) corren fuera de los módulos de feature y son el motor de notificaciones push proactivas (presupuestos, recordatorios, resumen semanal, insights, deudas de grupo, recurrencia de gastos compartidos).

---

## Estructura de Carpetas

```
Presupuesto/
├── docker-compose.yml          # api + postgres + redis, dev con hot reload
├── gen-hash.js / update-pass.js  # scripts puntuales de utilidad (hash bcrypt, reseteo de password) — NO parte de la app
├── qa/                          # scripts PowerShell de QA manual (debug, smoke tests, triggers de jobs)
├── backend/                     # API NestJS
│   ├── data-source.ts           # DataSource standalone para CLI de TypeORM (migraciones/seeds)
│   └── src/
│       ├── main.ts              # bootstrap (entry point HTTP)
│       ├── app.module.ts        # módulo raíz, registra todo
│       ├── config/              # 6 config factories (app, database, redis, jwt, aws, google)
│       ├── common/              # decoradores, filtros, interceptores, servicios transversales, utils
│       ├── database/
│       │   ├── migrations/      # 11 migraciones TypeORM (esquema completo)
│       │   └── seeds/           # categorías de sistema, datos demo, seed de stress-test de insights
│       ├── jobs/                # 6 cron jobs (notificaciones proactivas)
│       └── modules/              # 1 carpeta por dominio de negocio (ver tabla abajo)
└── mobile/                      # App Flutter
    ├── lib/
    │   ├── main.dart            # entry point Flutter
    │   ├── core/                # capa transversal: router, network, storage, theme, services, providers
    │   └── features/             # 1 carpeta por feature de UI (ver tabla abajo)
    ├── android/, assets/        # config nativa Android, iconos/imágenes/lottie
    └── pubspec.yaml             # dependencias Flutter
```

### Carpetas de `backend/src/modules/` (15 módulos de feature)

| Carpeta | Responsabilidad |
|---|---|
| `auth/` | Registro, login, refresh/rotación de tokens, logout, Google Sign-In |
| `users/` | Perfil del usuario, preferencias de notificación |
| `categories/` | Taxonomía jerárquica de categorías (sistema + custom) |
| `incomes/` | Fuentes de ingreso + historial de cobros + proyección |
| `expenses/` | Gastos personales (núcleo transaccional) + auto-categorización |
| `budgets/` | Presupuestos por categoría/periodo con alertas de umbral |
| `cash/` | Cuentas de efectivo (billeteras) y sus movimientos |
| `goals/` | Metas de ahorro y contribuciones |
| `analytics/` | Cálculos agregados: dashboard, tendencias, anomalías, simulación |
| `insights/` | Motor de generación de insights/alertas financieras |
| `rules/` | Automatizaciones "si esto, entonces aquello" (parcialmente conectado) |
| `credit-cards/` | Tarjetas de crédito, ciclos de facturación, pagos |
| `categorization/` | Motor de auto-categorización (reglas + aprendizaje por usuario) |
| `shared-groups/` | Grupos de gastos compartidos, balances, liquidaciones (feature nueva) |
| *(sin carpeta propia)* `common/services` | `PushNotificationService`, `NotificationRoutingService` — notificaciones globales |

### Carpetas de `mobile/lib/features/` (16 features)

| Carpeta | Responsabilidad |
|---|---|
| `auth/` | Login, registro, PIN local, Google Sign-In, restauración de sesión |
| `home/` | Dashboard principal, insights, accesos rápidos |
| `onboarding/` | Carrusel de bienvenida (6 slides) |
| `settings/` | Perfil, tema, categorías, notificaciones, calculadora de préstamos |
| `shared/` | UI de grupos de gastos compartidos (nueva, espejo de `shared-groups` backend) |
| `expenses/` | Listado/alta/edición de gastos + sugerencia de categoría |
| `incomes/` | Gestión de fuentes de ingreso |
| `budgets/` | Gestión de presupuestos |
| `cash/` | Cuentas de efectivo |
| `credit_cards/` | Tarjetas de crédito, ciclos, pagos, notificaciones locales |
| `goals/` | Metas de ahorro |
| `rules/` | Reglas de automatización |
| `analytics/` | Gráficos de tendencias/anomalías/métodos de pago + simulador |
| `achievements/` | Vitrina de logros (reusa datos de `home`, sin modelo propio) |

---

## Mapa de Archivos

### Backend — `main.ts` / `app.module.ts`

- **`backend/src/main.ts`** — Bootstrap: `setGlobalPrefix('api/v1')`, CORS (abierto en dev, restringido por `ALLOWED_ORIGINS` en prod), `ValidationPipe` global (whitelist + forbidNonWhitelisted + transform), `AllExceptionsFilter` global, interceptores `LoggingInterceptor`→`TransformInterceptor`→`ClassSerializerInterceptor`. Relacionado: todo `common/filters`, `common/interceptors`.
- **`backend/src/app.module.ts`** — Módulo raíz. Carga 6 configs (`ConfigModule.forRoot`), `TypeOrmModule`/`RedisModule`/`ThrottlerModule` async vía `ConfigService`, `ScheduleModule.forRoot()`, los 15 módulos de feature, y registra `TypeOrmModule.forFeature([...])` extra a nivel de AppModule solo para que los 6 **jobs** puedan inyectar repos de `User/Budget/Expense/Insight` + entidades de `shared-groups`. Providers globales: `GlobalJwtAuthGuard` (APP_GUARD), `ThrottlerGuard` (APP_GUARD), los 6 jobs, `PushNotificationService`, `NotificationRoutingService`.

### Backend — `config/`

| Archivo | Responsabilidad |
|---|---|
| `app.config.ts` | `NODE_ENV`, `PORT`, `API_PREFIX` |
| `database.config.ts` | Conexión TypeORM/Postgres (`synchronize:false`, SSL condicional, glob de entidades/migraciones) |
| `redis.config.ts` | Host/port/password Redis |
| `jwt.config.ts` | Secrets + expiraciones access/refresh (⚠️ fallback hardcodeado inseguro si no hay env var) |
| `aws.config.ts` | Credenciales S3 (declarado, sin SDK AWS instalado — no usado activamente) |
| `google.config.ts` | `GOOGLE_CLIENT_ID` para OAuth |

### Backend — `common/`

| Archivo | Responsabilidad |
|---|---|
| `decorators/current-user.decorator.ts` | `@CurrentUser()` — extrae `request.user` (poblado por `GlobalJwtAuthGuard`) |
| `decorators/public.decorator.ts` | `@Public()` + `IS_PUBLIC_KEY` — exime rutas del guard JWT global |
| `filters/all-exceptions.filter.ts` | Normaliza errores HTTP `{statusCode, timestamp, path, message}`, oculta detalle en prod para 500 |
| `interceptors/logging.interceptor.ts` | Log de cada request (método/URL/ms) |
| `interceptors/transform.interceptor.ts` | Envuelve toda respuesta exitosa en `{data, meta?}` |
| `utils/date-cycle.util.ts` | `getCurrentPeriod`/`getNextPeriod`/`daysRemainingInPeriod` — cálculo de ciclos quincenal/semanal/mensual (crítico para `analytics`, `budgets`) |
| `utils/encryption.util.ts` | AES-256-CBC `encrypt`/`decrypt` (⚠️ sin consumidor visible; fallback de clave insegura) |
| `utils/pagination.util.ts` | `parsePagination`/`buildMeta` reutilizados por controllers de listados |
| `services/push-notification.service.ts` | Envío push FCM con cap diario de 3/usuario vía Redis, modo "stub" si Firebase no está configurado |
| `services/notification-routing.service.ts` | Reglas de enrutamiento push/in-app por tipo de insight + cooldowns (`INSIGHT_COOLDOWN_HOURS`) |

### Backend — `database/`

- **`backend/data-source.ts`** — `DataSource` standalone (CLI TypeORM), usado por `migration:run`/`seed`. Duplica defaults de `database.config.ts` (mantener sincronizados manualmente).
- **`migrations/`** — ver tabla completa en sección [Base de Datos](#base-de-datos).
- **`seeds/categories.seed.ts`** — siembra ~12 categorías padre de gasto + 5 de ingreso (idempotente).
- **`seeds/demo-data.seed.ts`** — datos demo realistas (ene–abr 2026): tarjetas, ~50 gastos, presupuestos, metas, insights de muestra.
- **`seeds/run-seeds.ts`** — entry point `npm run seed` (corre categories + demo-data).
- **`seeds/insight-test.seed.ts`** — datos sintéticos diseñados para disparar cada tipo de insight (stress test del generador).

### Backend — `jobs/` (cron jobs)

Ver tabla completa en [Cron Jobs](#cron-jobs) más abajo. Archivos: `budget-alerts.job.ts`, `daily-reminder.job.ts`, `insights-generator.job.ts`, `weekly-summary.job.ts`, `debt-reminder.job.ts`, `shared-recurring.job.ts`.

### Backend — módulo `auth/`

| Archivo | Responsabilidad |
|---|---|
| `auth.module.ts` | Registra `User`, Passport, `JwtModule.register({})` (secrets inyectados por-request vía ConfigService) |
| `auth.controller.ts` | `POST register/login/refresh/logout/google` |
| `auth.service.ts` | `register` (bcrypt 12 rounds), `validateUser`, `login`, `refresh` (rotación + blacklist Redis), `logout` (blacklist), `googleLogin`/`verifyGoogleToken`/`validateOrCreateGoogleUser` (OAuth2Client), `generateTokens`, `parseTtl` |
| `dto/{google-auth,login,refresh-token,register}.dto.ts` | DTOs de validación (`class-validator`) |
| `guards/global-jwt-auth.guard.ts` | Guard global (APP_GUARD); respeta `@Public()` vía `Reflector` |
| `guards/jwt-auth.guard.ts` | Guard JWT simple, sin uso activo detectado (posible legado) |
| `guards/local-auth.guard.ts` | Activa estrategia `'local'` para login |
| `strategies/jwt.strategy.ts` | Extrae Bearer token, verifica con `jwt.secret`, resuelve `User` activo |
| `strategies/local.strategy.ts` | Valida email/password vía `AuthService.validateUser` |

⚠️ **PIN/biometría**: `User.pinHash`/`biometricEnabled` existen como columnas pero **no hay ningún endpoint backend** que los gestione — el PIN es 100% client-side en mobile (`flutter_secure_storage`).

### Backend — módulo `users/`

| Archivo | Responsabilidad |
|---|---|
| `users.module.ts` | Registra `User`, `UserNotificationPreferences`; provee/exporta `UsersService`, `NotificationPreferencesService` |
| `users.controller.ts` | `GET/PATCH/DELETE /users/me`, `GET/PATCH /users/me/notification-preferences` |
| `users.service.ts` | `findById`, `update`, `softDelete` (vía `deletedAt`), `updateAvatar` |
| `user.entity.ts` | Entidad raíz `User` — auth, perfil, preferencias financieras (`payCycle`, `experienceMode`), `fcmToken`, relaciones `OneToMany` a casi todos los módulos |
| `user-notification-preferences.entity.ts` | ~16 flags de notificación (push/local-tarjeta/in-app/grupos compartidos) + `debtReminderDays` |
| `notification-preferences.service.ts` | `findOrCreateDefaults`, `update` (lazy-create + patch) |
| `dto/update-user.dto.ts` | Campos de perfil editables (NO incluye pin/password) |
| `dto/notification-preferences.dto.ts` | Patch parcial de preferencias |

### Backend — módulo `shared-groups/` (feature nueva)

| Archivo | Responsabilidad |
|---|---|
| `shared-groups.module.ts` | Registra 8 entidades + `CashModule`; 2 controllers, 4 services |
| `shared-groups.dto.ts` | TODOS los DTOs del módulo (Create/Join/ParticipantShare/CreateExpense/UpdateExpense/UpdateSettings/Approve/ImportRow/CreateSettlement) |
| `shared-groups.controller.ts` | CRUD de grupos, join/leave/removeMember, balances, widget-summary, my-shared-expenses |
| `shared-groups.service.ts` | `createGroup` (genera código invite 8-hex), `getUserGroups`, `getGroupDetail`, `joinGroup`, `leaveGroup`, `removeMember`, `deleteGroup`, `assertActiveMember` (helper de autorización reusado por los demás services) |
| `shared-expenses.controller.ts` | CRUD de gastos compartidos, approve/reject, stats, export CSV, import, settings, settlements (anidado bajo `:groupId`) |
| `shared-expenses.service.ts` | `createSharedExpense` (valida cuotas suma=total, integra con `CashService`, push a participantes), `updateSharedExpense`/`deleteSharedExpense` (solo pagador), `getMySharedExpenses`, `approveExpense`/`rejectExpense` (⚠️ bug: reject revierte a `PENDING`, no a un estado "rejected"), `getGroupStats`, `exportGroupExpenses` (CSV), `importExpenses` |
| `balances.service.ts` | `getGroupBalances` (matriz neta deudor→acreedor con neteo bilateral), `getWidgetSummary` (agregado cross-grupo, ⚠️ accede a propiedad privada de `SharedGroupsService`) |
| `settlements.service.ts` | `createSettlement` (con impacto opcional en efectivo), `getGroupSettlements` |
| `entities/shared-group.entity.ts` | Grupo raíz: `ownerId`, `inviteCode`, `isActive` |
| `entities/shared-group-member.entity.ts` | Membresía (`status`: active/removed/left) |
| `entities/shared-group-invite.entity.ts` | Código de invitación (`maxUses`, `uses`, `expiresAt`) |
| `entities/shared-group-settings.entity.ts` | `requiresApproval` por grupo (creación on-demand) |
| `entities/shared-expense.entity.ts` | Gasto compartido (`status`: approved/pending; recurrencia: `isRecurring`/`recurringInterval`/`nextRecurrenceAt`) |
| `entities/shared-expense-participant.entity.ts` | Cuota individual (`shareAmount`) por participante |
| `entities/shared-expense-approval.entity.ts` | Decisión del owner (pending/approved/rejected) |
| `entities/shared-settlement.entity.ts` | Pago de liquidación entre dos miembros |

### Backend — módulos financieros core (expenses/incomes/budgets/cash/credit-cards/categories/categorization/goals/rules)

| Módulo | Archivos clave | Responsabilidad resumida |
|---|---|---|
| `expenses/` | `expense.entity.ts`, `expenses.service.ts`, `expenses.controller.ts`, `dto/expense.dto.ts` | Núcleo transaccional: CRUD de gastos, deduplicación (ventana 5s), auto-categorización al crear, descuento/reversión automática de saldo de efectivo, reportes por categoría/método de pago |
| `incomes/` | `income.entity.ts`, `income-record.entity.ts`, `incomes.service.ts` | Fuentes de ingreso + historial real de cobros + proyección a 90 días |
| `budgets/` | `budget.entity.ts`, `budgets.service.ts` | Presupuestos por categoría/periodo; calcula `spent`/`percentage` vía query cruda a `expenses`; valida solapamiento; `checkAndMarkAlerts` (usado por `budget-alerts.job.ts`) |
| `cash/` | `cash-account.entity.ts`, `cash-transaction.entity.ts`, `cash.service.ts` | Billeteras de efectivo, depósito/retiro, integración bidireccional con `expenses` |
| `credit-cards/` | `credit-card.entity.ts`, `credit-card-payment.entity.ts`, `credit-cards.service.ts` | Ciclo de facturación (corte/vencimiento), saldos por moneda, `paymentStatus`, `utilizationPct` — lógica de fechas más compleja del backend |
| `categories/` | `category.entity.ts`, `categories.service.ts` | Taxonomía jerárquica (parent/children), sistema vs. custom, protección contra borrado si tiene gastos |
| `categorization/` | `categorization-rules.service.ts` (diccionario keywords/merchants HN), `categorization-learning.service.ts` (aprendizaje por usuario), `expense-categorization.service.ts` (orquestador, `suggest`/`shouldAutoAssign`), `categorization-metrics.service.ts`, entidades `user-category-mapping.entity.ts`/`categorization-audit-log.entity.ts` | Motor de auto-categorización: prioridad aprendizaje-usuario > reglas globales; usado por `expenses.service.ts` |
| `goals/` | `goal.entity.ts`, `goal-contribution.entity.ts`, `goals.service.ts` | Metas de ahorro, contribuciones manuales, auto-complete al alcanzar target |
| `rules/` | `rule.entity.ts`, `rules-evaluator.service.ts`, `rules.service.ts` | Motor "si-entonces" (condiciones/acciones en JSONB); ⚠️ `evaluateOnExpense` existe pero **no se encontró integración real** que lo invoque desde `ExpensesService.create` |

### Backend — `analytics/` e `insights/`

| Archivo | Responsabilidad |
|---|---|
| `analytics/analytics.service.ts` | `getDashboard` (balance, riesgo green/yellow/red, `cashRunoutDate`), `getSpendingTrends`, `detectAnomalies` (z-score semanal por categoría), `getPaymentMethodTrends`, `getSimulation` (proyección de ahorro). Solo lectura/agregación |
| `analytics/analytics.controller.ts` | `GET /analytics/{dashboard,spending-trends,payment-method-trends,anomalies,simulation}` |
| `insights/insight.entity.ts` | Entidad `Insight` (`type`: savings_opportunity/anomaly/projection/streak/budget_warning/pattern/achievement; `priority`: low/medium/high/critical) |
| `insights/insights-generator.service.ts` | `generateForUser` orquesta 7 sub-generadores en paralelo (anomalía, presupuesto, proyección, patrón, ahorro, racha, logros); anti-duplicación vía cooldown; `sendInsightPush` |
| `insights/insights.service.ts` | CRUD de insights ya generados: `findActive`, `findAchievements`, `markRead`, `dismiss`/`dismissAll` |
| `insights/insights.controller.ts` | `GET /insights`, `GET /insights/achievements`, `POST /insights/regenerate`, `POST /insights/test-push`, `PATCH /insights/:id/read`, `DELETE /insights/:id`, `DELETE /insights/dismiss-all` |

### Mobile — `main.dart` + `core/`

| Archivo | Responsabilidad |
|---|---|
| `main.dart` | Init Hive (`preferences` box), `NotificationService.initialize()`, Firebase (tolerante a fallo), `FcmService.initialize()`, monta `ProviderScope(FinanzasApp)` |
| `core/constants/api_constants.dart` | **Fuente única de verdad** de `baseUrl` + TODOS los endpoints REST (incluye builders parametrizados para `shared-groups`) |
| `core/constants/currency_format.dart` | `currencyFmt(currency)` — formato monetario por moneda (HNL/USD/GTQ/MXN/CRC/NIO) |
| `core/constants/storage_keys.dart` | Claves de Hive/secure storage centralizadas |
| `core/network/dio_client.dart` | `dioProvider` — cliente Dio único: interceptor de desempaquetado `{data}`, inyección de Bearer token, **refresh automático de token en 401 + retry**, `PrettyDioLogger` |
| `core/presentation/screens/app_shell.dart` | `ShellRoute` builder — bottom nav (6 tabs avanzado / 5 simple), FAB condicional, `OfflineBanner`, refresca providers al volver de background |
| `core/presentation/screens/splash_screen.dart` | Ruta inicial; decide login/onboarding/home tras 1.5s según `authStateProvider` |
| `core/presentation/widgets/app_error_widget.dart` | Error widget reusable, mapea `DioException`/`SocketException` a mensajes en español |
| `core/presentation/widgets/offline_banner.dart` | Banner animado de "sin conexión" (`isOnlineProvider`) |
| `core/providers/connectivity_provider.dart` | `connectivityProvider`/`isOnlineProvider` (basado en `connectivity_plus`) |
| `core/providers/experience_provider.dart` | `ExperienceModeNotifier` — modo simple/avanzado con sync optimista a `PATCH /users/me` |
| `core/providers/tutorial_provider.dart` | DI wrapper de `TutorialService` |
| `core/router/app_router.dart` | `GoRouter` completo — TODAS las rutas + `ShellRoute` + guard de redirect auth/onboarding (`_AuthRouterNotifier`) |
| `core/services/fcm_service.dart` | Permisos FCM, manejo foreground/background, `registerToken` (`PATCH /users/me`), mapea push→ruta interna |
| `core/services/notification_service.dart` | `flutter_local_notifications` — instantáneas + programadas (cutoff/pago/vencido de tarjetas) |
| `core/services/tutorial_service.dart` | Flag de onboarding completado (Hive) |
| `core/storage/token_storage.dart` | `TokenStorage` sobre `flutter_secure_storage` — tokens + usuario cacheado |
| `core/theme/app_colors.dart` / `app_theme.dart` | Paleta de marca + `ThemeData` M3 claro/oscuro, persistencia de modo en Hive |

### Mobile — features

| Feature | Archivos clave | Notas |
|---|---|---|
| `auth/` | `auth_models.dart`, `login_screen.dart`, `register_screen.dart`, `pin_setup_screen.dart`, `auth_provider.dart` (AsyncNotifier central), `auth_repository.dart`, `google_auth_service.dart` | PIN se guarda solo localmente (`secureStorageProvider`); `tryRestoreSession` cachea usuario para modo offline |
| `home/` | `dashboard_model.dart`, `dashboard_provider.dart`, `home_screen.dart` | Combina 3 respuestas backend (dashboard+summary+expenses) en `DashboardModel`; panel de insights; `_SharedSummaryCard` si hay grupos |
| `onboarding/` | `onboarding_screen.dart` | 6 slides (incluye uno de grupos compartidos); expone `hasCompletedOnboarding()`/`markOnboardingDone()` top-level |
| `settings/` | `settings_screen.dart`, `notification_settings_screen.dart`, `categories_management_screen.dart`, `loan_calculator_screen.dart`, `notification_prefs_provider.dart` | Calculadora de préstamos es 100% local/offline (sin Riverpod ni red) |
| `shared/` (nueva) | `shared_group_model.dart`, `shared_expense_model.dart`, `shared_balance_model.dart`, `shared_settlement_model.dart`, `shared_groups_provider.dart`, `shared_expenses_provider.dart`, `shared_settlements_provider.dart`, `shared_groups_screen.dart`, `shared_group_detail_screen.dart`, `add_shared_expense_screen.dart` | Espejo completo del backend `shared-groups`; export PDF/CSV vía `pdf`+`share_plus`+`path_provider` |
| `expenses/` | `expenses_provider.dart` (modelo+categorías+sugerencia+feedback), `expenses_list_screen.dart`, `add_expense_screen.dart` | Fusiona gastos personales + compartidos (`/shared-groups/my-shared-expenses`); auto-categorización con debounce 600ms |
| `incomes/` | `incomes_screen.dart` (modelo+provider+screen co-localizados) | Dispara `POST /insights/regenerate` tras cambios |
| `budgets/` | `budgets_screen.dart` (co-localizado) | Reusa `categoriesProvider` de `expenses_provider.dart` |
| `cash/` | `cash_models.dart`, `cash_provider.dart`, `cash_screen.dart` | Crea cuenta default si no existe |
| `credit_cards/` | `credit_card_model.dart`, `credit_cards_provider.dart`, `credit_cards_screen.dart` | Reprograma notificaciones locales (`NotificationService.rescheduleAll`) en cada cambio de resumen |
| `goals/` | `goals_screen.dart` (co-localizado) | Selector de emoji custom, `POST /goals/:id/contribute` |
| `rules/` | `rules_screen.dart` (co-localizado) | Feature más aislado, sin dependencias cross-feature |
| `analytics/` | `analytics_screen.dart` (4 tabs + `fl_chart`), `simulator_screen.dart` | ⚠️ usa literal `/analytics/anomalies` (no está en `ApiConstants`) |
| `achievements/` | `achievements_screen.dart` | **Sin modelo/provider propio** — reusa `achievementsProvider`/`InsightModel` de `home/` |

---

## Flujos de Negocio

### 1. Registro → PIN → Onboarding → Home
1. `register_screen.dart` → `authStateProvider.notifier.register()` (`auth_provider.dart`) → `AuthRepository.register()` (`auth_repository.dart`): `POST /auth/register` → backend `AuthController.register` → `AuthService.register` (bcrypt 12 rounds, `ConflictException` si email existe) → genera tokens.
2. Mobile guarda tokens (`TokenStorage`), hace `GET /me`, cachea usuario, llama `TutorialService().resetAll()`.
3. Router (`app_router.dart`, `_AuthRouterNotifier`) redirige a `pin_setup_screen.dart` → PIN de 6 dígitos guardado en `secureStorageProvider` (**solo local, sin backend**).
4. Si `!hasCompletedOnboarding()` → `onboarding_screen.dart` (6 slides) → `markOnboardingDone()` → `AppRoutes.home`.

### 2. Login (email/password y Google)
- Email: `login_screen.dart` → `AuthRepository.login()` → `POST /auth/login` (`LocalAuthGuard`→`LocalStrategy`→`AuthService.validateUser` con bcrypt) → tokens → `GET /me`.
- Google: `GoogleAuthService.signIn()` (idToken nativo) → `POST /auth/google` → `AuthService.googleLogin` → `verifyGoogleToken` (`google-auth-library`) → `validateOrCreateGoogleUser` (vincula cuenta existente por email o crea nueva con `passwordHash:null`).
- Cada request autenticado: `GlobalJwtAuthGuard` (app.module.ts, APP_GUARD) → si no es `@Public()` → `JwtStrategy.validate` busca `User` activo por `payload.sub`.
- 401 en mobile → `dio_client.dart` intercepta, hace `POST /auth/refresh` con refresh token, reintenta request original.
- Refresh en backend: `AuthService.refresh` verifica firma, chequea blacklist Redis, **invalida el token usado** (rotación single-use), emite nuevo par.

### 3. Crear un gasto (con auto-categorización y efectivo)
1. `add_expense_screen.dart` → debounce 600ms → `POST /expenses/suggest-category` (`expenses.controller.ts` → `ExpenseCategorizationService.suggest`: prioridad aprendizaje-usuario > reglas globales (`categorization-rules.service.ts`, diccionario HN)).
2. Usuario confirma/cambia categoría → `POST /expenses` → `ExpensesService.create`: valida fecha no futura, detecta duplicado (ventana 5s), si no hay `categoryId` auto-asigna si confianza="high" (`shouldAutoAssign`), persiste `Expense`, escribe `CategorizationAuditLog`.
3. Si `paymentMethod=cash`: descuenta saldo de `CashAccount` (default o más antigua) y crea `CashTransaction` tipo SPEND.
4. Si el usuario corrigió la categoría sugerida → `POST /categorization/feedback` → `CategorizationLearningService.recordFeedback` (alimenta `UserCategoryMapping`).
5. Mobile invalida `expensesProvider`, `dashboardProvider`, y si era con tarjeta, `creditCardsSummaryProvider`.

### 4. Generación de Insights y notificación push
1. Tres triggers: on-demand (`GET /insights` si vacío), manual (`POST /insights/regenerate`), o cron `InsightsGeneratorJob` (2 AM diario, todos los usuarios activos).
2. `InsightsGeneratorService.generateForUser` corre 7 sub-generadores en paralelo, cada uno con cooldown anti-duplicado (`INSIGHT_COOLDOWN_HOURS` en `notification-routing.service.ts`).
3. Cada insight válido se persiste en `insights` (tabla) y, según preferencias del usuario (`UserNotificationPreferences`) y tipo, dispara push vía `PushNotificationService.send` (cap diario 3, Redis).
4. Mobile recibe via `FcmService` (foreground) → `NotificationService.showInstant`; o lo lista en `GET /insights` → panel en `home_screen.dart`.

### 5. Grupos de gastos compartidos — crear grupo → gasto → liquidar
1. `shared_groups_screen.dart` → "Crear grupo" → `POST /shared-groups` → `SharedGroupsService.createGroup` (genera `inviteCode` 8-hex, auto-agrega owner como `ACTIVE`).
2. Otro usuario → "Unirse" con código → `POST /shared-groups/join` → valida expiración/usos del invite → crea/reactiva membresía.
3. `add_shared_expense_screen.dart` → división por igual/%/monto fijo con auto-balanceo → `POST /shared-groups/:groupId/expenses` → `SharedExpensesService.createSharedExpense`: valida membresía de todos, valida `Σ shareAmount == totalAmount` (±0.01), nace `PENDING` o `APPROVED` según `SharedGroupSettings.requiresApproval`; si paga el actor en efectivo con cuenta indicada, retira de `CashAccount`; notifica a participantes.
4. Si requiere aprobación: owner `PATCH .../approve` o `.../reject` (⚠️ reject no cambia el status del gasto principal, solo registra en `SharedExpenseApproval`).
5. `GET /shared-groups/:id/balances` → `BalancesService.getGroupBalances`: reconstruye deudas brutas por gasto, resta `SharedSettlement` ya aplicados, "netea" cada par de usuarios.
6. Liquidar: `_SettlementSheet` (UI) → `POST /shared-groups/:groupId/settlements` → `SettlementsService.createSettlement` (impacto opcional en efectivo, notifica al receptor).
7. Recurrencia automática: `SharedRecurringJob` (cron 8 AM) clona gastos con `nextRecurrenceAt` vencido. Deudas vencidas: `DebtReminderJob` (cron 10 AM) calcula deuda neta no liquidada por antigüedad y notifica según `debtReminderDays` del usuario.

### 6. Presupuestos y alertas de umbral
1. `budgets_screen.dart` crea presupuesto (`POST /budgets`) → `BudgetsService.create` valida no-solapamiento (misma categoría+tipo+rango).
2. `BudgetAlertsJob` (cron cada hora) recalcula gasto real (`expenses` cruzado por categoría+rango), llama `BudgetsService.checkAndMarkAlerts`, marca `alert50/80/100Sent` y dispara push solo al cruzar un nuevo umbral.

### 7. Tarjetas de crédito — ciclo de facturación
1. `credit_cards_screen.dart` → `POST /credit-cards` (cutOffDay, paymentDueDays, creditLimit).
2. `CreditCardsService.getSummary` → `buildCardSummary`: calcula ciclo actual/cerrado (`computeBillingCycle`), suma gastos por moneda en cada ciclo, determina `paymentStatus` (paid/partial/unpaid/no_debt) basado **solo** en deuda del ciclo cerrado, calcula `utilizationPct`.
3. Mobile reprograma notificaciones locales (`NotificationService.rescheduleAll`) cada vez que cambia el resumen (cutoff -3d, pago -5d/-1d, vencido).

---

## Puntos de Entrada

| Entry point | Archivo | Descripción |
|---|---|---|
| API HTTP | `backend/src/main.ts` | `bootstrap()` → Nest app escuchando en `PORT` (default 3000), prefijo `api/v1` |
| App móvil | `mobile/lib/main.dart` | `void main()` → init Hive/Notifications/Firebase → `runApp(ProviderScope(FinanzasApp))` |
| CLI migraciones | `backend/data-source.ts` + scripts `migration:generate/run/revert` en `package.json` | Usa `typeorm-ts-node-commonjs` |
| CLI seeds | `backend/src/database/seeds/run-seeds.ts` | `npm run seed` |
| Cron jobs | `backend/src/jobs/*.job.ts` (6 archivos) | Registrados como providers en `app.module.ts`, activados por `ScheduleModule.forRoot()` |
| Docker | `docker-compose.yml` | `api` (build desde `./backend`), `postgres:15-alpine`, `redis:7-alpine` |
| Scripts sueltos | `gen-hash.js`, `update-pass.js` (raíz) | Utilidades puntuales fuera de la app (generar hash bcrypt / resetear password manualmente) |
| QA manual | `qa/*.ps1` | Scripts PowerShell de debug/smoke test (no son parte del pipeline de tests automatizado) |

---

## APIs

### Auth / Users
| Method | Path | Auth | Descripción |
|---|---|---|---|
| POST | /auth/register | No | Registro + tokens |
| POST | /auth/login | No (LocalAuthGuard) | Login email/password |
| POST | /auth/refresh | No | Rota refresh token |
| POST | /auth/logout | Sí | Blacklist refresh token |
| POST | /auth/google | No | Login/registro vía Google |
| GET/PATCH/DELETE | /users/me | Sí | Perfil del usuario |
| GET/PATCH | /users/me/notification-preferences | Sí | Preferencias de notificación |

### Dominio financiero
| Method | Path | Descripción |
|---|---|---|
| GET/POST/PATCH/DELETE | /expenses(/:id) | CRUD de gastos |
| GET | /expenses/summary, /expenses/summary-by-method | Agregados por categoría/método |
| POST | /expenses/suggest-category | Sugerencia de categoría (no persiste) |
| GET/POST/PATCH/DELETE | /incomes(/:id) | CRUD de ingresos |
| GET | /incomes/projection | Proyección 90 días |
| POST/GET | /incomes/:id/records | Registrar/listar cobros |
| GET/POST/PATCH/DELETE | /budgets(/:id) | CRUD de presupuestos (con spent/percentage) |
| GET/POST | /cash/accounts | Cuentas de efectivo |
| POST | /cash/accounts/:id/deposit, /withdraw | Movimientos |
| GET | /cash/accounts/:id/transactions | Historial |
| GET/POST/PATCH/DELETE | /credit-cards(/:id) | CRUD de tarjetas |
| GET | /credit-cards/summary | Resumen de ciclo/saldo/utilización |
| POST/GET | /credit-cards/:id/payments | Registrar/listar pagos |
| GET/POST/PATCH/DELETE | /categories(/:id) | CRUD de categorías custom |
| POST | /categorization/feedback | Feedback de categoría elegida |
| GET | /categorization/stats | Métricas de precisión del motor |
| GET/POST/PATCH/DELETE | /goals(/:id) | CRUD de metas |
| POST | /goals/:id/contribute | Aporte a meta |
| GET/POST/PATCH/DELETE | /rules(/:id) | CRUD de reglas de automatización |

### Analytics / Insights
| Method | Path | Descripción |
|---|---|---|
| GET | /analytics/dashboard | Balance/riesgo/proyección del período |
| GET | /analytics/spending-trends, /payment-method-trends, /anomalies | Tendencias y anomalías |
| GET | /analytics/simulation | Simulación de ahorro |
| GET | /insights, /insights/achievements | Insights activos / logros |
| POST | /insights/regenerate, /insights/test-push | Forzar regeneración / push de prueba |
| PATCH/DELETE | /insights/:id/read, /insights/:id, /insights/dismiss-all | Marcar leído / descartar |

### Shared Groups (gastos compartidos)
| Method | Path | Descripción |
|---|---|---|
| POST/GET | /shared-groups | Crear / listar grupos |
| GET | /shared-groups/widget-summary, /my-shared-expenses | Resumen agregado / todos los gastos cross-grupo |
| GET/DELETE | /shared-groups/:id | Detalle / eliminar grupo |
| POST | /shared-groups/join | Unirse con código |
| DELETE | /shared-groups/:id/leave, /:id/members/:userId | Salir / expulsar |
| GET | /shared-groups/:id/balances | Matriz de deudas netas |
| POST/GET/PATCH/DELETE | /shared-groups/:groupId/expenses(/:expenseId) | CRUD de gastos compartidos |
| PATCH | /shared-groups/:groupId/expenses/:expenseId/{approve,reject} | Flujo de aprobación |
| GET | /shared-groups/:groupId/stats, /export/csv | Estadísticas / exportar |
| POST | /shared-groups/:groupId/import | Importar gastos masivamente |
| GET/PATCH | /shared-groups/:groupId/settings | Config del grupo (requiresApproval) |
| POST/GET | /shared-groups/:groupId/settlements | Crear/listar liquidaciones |

---

## Base de Datos

### Entidades principales
`User`, `Category` (jerárquica), `Expense`, `Income`/`IncomeRecord`, `Budget`, `CashAccount`/`CashTransaction`, `CreditCard`/`CreditCardPayment`, `Goal`/`GoalContribution`, `Insight`, `Rule`, `UserCategoryMapping`/`CategorizationAuditLog`, `UserNotificationPreferences`, `SharedGroup`/`SharedGroupMember`/`SharedGroupInvite`/`SharedGroupSettings`/`SharedExpense`/`SharedExpenseParticipant`/`SharedExpenseApproval`/`SharedSettlement`.

### Relaciones clave
- `User` (1)→(N) casi todo: `Expense`, `Income`, `Category` (propias), `Budget`, `Goal`, `CashAccount`, `Insight`, `Rule`.
- `Category` (1)→(N) `Category` (auto-referencia parent/children), `Expense`, `Budget` (opcional).
- `CashAccount` (1)→(N) `CashTransaction`, `Expense` (opcional); `Expense` (1)→(0..1) `CashTransaction` (reversión de saldo).
- `CreditCard` (1)→(N) `Expense`, `CreditCardPayment`.
- `Income` (1)→(N) `IncomeRecord`. `Goal` (1)→(N) `GoalContribution`.
- `SharedGroup` (1)→(N) `SharedGroupMember`/`SharedGroupInvite`/`SharedExpense`/`SharedSettlement`; `SharedExpense` (1)→(N) `SharedExpenseParticipant`, (1)→(0..1) `SharedExpenseApproval`.
- Relaciones **lógicas sin FK formal**: `Budget`↔`Expense` (query cruda por `user_id`+rango+categoría), `Rule.conditions/actions` (JSONB, referencian campos de `Expense` por nombre lógico).

### Migraciones (orden cronológico)
| Migration | Cambio |
|---|---|
| `1775450123406-InitialSchema` | Esquema base completo (users, categories, incomes, expenses, budgets, goals, insights, rules, cash) |
| `1775500000000-AddOauthProviderToUsers` | `provider`/`providerId` en users, password nullable |
| `1775800000000-AddCreditCardsModule` | Tabla `credit_cards` + FK en expenses |
| `1775900000000-AddLimitCurrencyToCreditCards` | `limit_currency` en credit_cards |
| `1775965000000-AddAchievementInsightType` | Enum value `'achievement'` (⚠️ down() no-op, irreversible) |
| `1776000000000-AddCreditCardPayments` | Tabla `credit_card_payments` |
| `1776100000000-AddExperienceModeToUsers` | Enum + columna `experience_mode` |
| `1776200000000-AddCategorizationTables` | `user_category_mappings`, `categorization_audit_logs` |
| `1776300000000-AddNotificationPreferences` | Tabla `user_notification_preferences` |
| `1776400000000-AddSharedGroups` | Subsistema completo de grupos compartidos |
| `1776500000000-SharedExpensesFeatures` | Recurrencia + aprobación en shared_expenses; `shared_group_settings`, `shared_expense_approvals` |

### Cron Jobs
| Job | Horario | Propósito |
|---|---|---|
| `budget-alerts.job.ts` | Cada hora | Umbrales 50/80/100% de presupuesto → push |
| `daily-reminder.job.ts` | 8:00 AM | Recordatorio contextual (sin gasto 24h / budget warning / racha en riesgo) |
| `insights-generator.job.ts` | 2:00 AM | Purga expirados + regenera insights + push de mayor prioridad |
| `weekly-summary.job.ts` | Lunes 9:00 AM | Resumen semanal de gasto vs. semana anterior |
| `debt-reminder.job.ts` | 10:00 AM | Deuda neta de grupos compartidos no liquidada (por `debtReminderDays`) |
| `shared-recurring.job.ts` | 8:00 AM | Clona gastos compartidos recurrentes vencidos |

---

## Dependencias Críticas

### Backend
| Librería | Dónde se usa |
|---|---|
| `typeorm` + `pg` | Toda la capa de persistencia, todas las entidades |
| `@nestjs/jwt`, `passport-jwt`, `passport-local` | `auth/` (estrategias, generación/verificación de tokens) |
| `bcrypt` | `auth.service.ts` (hash de password, 12 rounds) |
| `google-auth-library` | `auth.service.ts` (`verifyGoogleToken`) |
| `@nestjs-modules/ioredis` / `ioredis` | `push-notification.service.ts` (cap diario), `auth.service.ts` (blacklist refresh tokens) |
| `firebase-admin` | `push-notification.service.ts` (envío FCM, carga dinámica con `require`) |
| `@nestjs/schedule` | Los 6 cron jobs en `jobs/` |
| `@nestjs/throttler` | Rate limiting global (`app.module.ts`) |
| `@nestjs/bull` + `bull` | Declarado, **sin uso visible** en el código analizado |
| `class-validator`/`class-transformer` | Todos los DTOs + `@Exclude()` en `User` (oculta passwordHash/pinHash) |

### Mobile
| Librería | Dónde se usa |
|---|---|
| `flutter_riverpod` | Estado global en absolutamente todos los features |
| `go_router` | `core/router/app_router.dart` (única fuente de rutas) |
| `dio` + `pretty_dio_logger` | `core/network/dio_client.dart` (cliente HTTP único) |
| `hive`/`hive_flutter` | Preferencias no sensibles (tema, flag onboarding) |
| `flutter_secure_storage` | Tokens, PIN, usuario cacheado |
| `firebase_core`/`firebase_messaging` | `fcm_service.dart` |
| `flutter_local_notifications` + `timezone` | `notification_service.dart` (alertas locales de tarjetas) |
| `google_sign_in` | `google_auth_service.dart` |
| `fl_chart` | `analytics_screen.dart` |
| `pdf` + `share_plus` + `path_provider` | Exportación de reportes en `shared_group_detail_screen.dart` (CSV/PDF) |
| `connectivity_plus` | `connectivity_provider.dart` (banner offline) |

---

## Guía de Modificaciones

| Funcionalidad | Archivos a tocar | Archivos a NO tocar | Riesgos |
|---|---|---|---|
| **Agregar campo a perfil de usuario** | `user.entity.ts`, `dto/update-user.dto.ts`, `users.service.ts`, mobile `auth_models.dart` + pantalla que lo edite, nueva migración | `auth.service.ts` (no toca perfil, solo identidad) | Olvidar migración rompe `synchronize:false`; recordar `@Exclude()` si es sensible |
| **Nuevo tipo de Insight** | `insight.entity.ts` (enum, migración `ADD VALUE` — ⚠️ irreversible en Postgres), `insights-generator.service.ts` (nuevo generador), `notification-routing.service.ts` (cooldown + reglas push), mobile `dashboard_model.dart`/`home_screen.dart` si necesita UI especial | `insights.service.ts` (CRUD genérico, no necesita cambios) | Enum de Postgres no permite `DROP VALUE` — pensar bien el nombre antes de migrar |
| **Cambiar reglas de auto-categorización** | `categorization-rules.service.ts` (diccionario `RULES`), `categorization.config.ts` (umbrales) | `categorization-learning.service.ts` (lógica de aprendizaje, independiente) | Cambiar umbrales afecta retroactivamente auto-asignación de gastos nuevos, no los existentes |
| **Nuevo endpoint en grupos compartidos** | `shared-groups.dto.ts` (DTO), `shared-expenses.controller.ts` o `shared-groups.controller.ts`, el service correspondiente, mobile `shared_*_provider.dart` + `api_constants.dart` | `balances.service.ts` (solo si no afecta cálculo de deudas) | `BalancesService.getWidgetSummary` accede a propiedad privada de `SharedGroupsService` — frágil ante refactors |
| **Cambiar lógica de ciclo de facturación de tarjetas** | `credit-cards.service.ts` (`computeBillingCycle`, `buildCardSummary`), mobile `credit_cards_screen.dart`, `notification_service.dart` (fechas de recordatorio) | `expense.entity.ts` (solo lee `creditCardId`, no cambia) | Es la lógica de fechas más compleja del backend; cualquier cambio requiere testear ciclos cruzando fin de mes |
| **Agregar canal/preferencia de notificación** | `user-notification-preferences.entity.ts` (+ migración), `dto/notification-preferences.dto.ts`, el job o service que la consulte, mobile `notification_prefs_provider.dart` + `notification_settings_screen.dart` | `push-notification.service.ts` (genérico, no necesita tocarse salvo cambiar el cap diario) | Olvidar default en la entidad rompe `findOrCreateDefaults` para usuarios existentes |
| **Modificar cálculo de balances/deudas** | `balances.service.ts` únicamente (algoritmo de neteo) | `shared-expenses.service.ts`, `settlements.service.ts` (solo proveen datos crudos) | El neteo bilateral usa tolerancia 0.005 — cambios de precisión pueden introducir deudas residuales fantasma |
| **Cambiar formato de respuesta API** | `common/interceptors/transform.interceptor.ts`, **todo** el mobile (`dio_client.dart` desempaqueta `{data}`) | — | Cambio rompe TODOS los repositorios mobile simultáneamente; requiere coordinar deploy backend+mobile |
| **Agregar nuevo cron job** | Nuevo archivo en `backend/src/jobs/`, registrarlo en `app.module.ts` (`providers` + posible `TypeOrmModule.forFeature`) | — | Jobs corren fuera de los módulos de feature; deben importar entidades explícitamente, fácil de olvidar |

---

## Índice de Búsqueda

| Funcionalidad | Archivo Principal | Archivos Relacionados |
|---|---|---|
| Login / registro / refresh tokens | `backend/src/modules/auth/auth.service.ts` | `auth.controller.ts`, `jwt.strategy.ts`, `local.strategy.ts`, mobile `auth_repository.dart`, `auth_provider.dart` |
| Login con Google | `backend/src/modules/auth/auth.service.ts` (`googleLogin`) | `google.config.ts`, mobile `google_auth_service.dart` |
| PIN local | mobile `pin_setup_screen.dart` | `token_storage.dart` (sin contraparte backend) |
| Perfil de usuario | `backend/src/modules/users/users.service.ts` | `user.entity.ts`, mobile `settings_screen.dart`, `auth_provider.dart` |
| Preferencias de notificación | `backend/src/modules/users/notification-preferences.service.ts` | `user-notification-preferences.entity.ts`, `notification-routing.service.ts`, mobile `notification_prefs_provider.dart` |
| Crear/editar gasto | `backend/src/modules/expenses/expenses.service.ts` | `expense.entity.ts`, `expense-categorization.service.ts`, `cash.service.ts`, mobile `add_expense_screen.dart`, `expenses_provider.dart` |
| Auto-categorización | `backend/src/modules/categorization/expense-categorization.service.ts` | `categorization-rules.service.ts`, `categorization-learning.service.ts`, `categorization-audit-log.entity.ts` |
| Presupuestos y alertas | `backend/src/modules/budgets/budgets.service.ts` | `budget.entity.ts`, `jobs/budget-alerts.job.ts`, mobile `budgets_screen.dart` |
| Cuentas de efectivo | `backend/src/modules/cash/cash.service.ts` | `cash-account.entity.ts`, `cash-transaction.entity.ts`, `expenses.service.ts`, mobile `cash_provider.dart` |
| Tarjetas de crédito / ciclo de facturación | `backend/src/modules/credit-cards/credit-cards.service.ts` | `credit-card.entity.ts`, `credit-card-payment.entity.ts`, mobile `credit_cards_screen.dart`, `notification_service.dart` |
| Categorías | `backend/src/modules/categories/categories.service.ts` | `category.entity.ts`, `categorization-rules.service.ts`, mobile `categories_management_screen.dart` |
| Metas de ahorro | `backend/src/modules/goals/goals.service.ts` | `goal.entity.ts`, `goal-contribution.entity.ts`, mobile `goals_screen.dart` |
| Reglas de automatización | `backend/src/modules/rules/rules-evaluator.service.ts` | `rule.entity.ts`, `rules.service.ts`, mobile `rules_screen.dart` |
| Dashboard / analítica | `backend/src/modules/analytics/analytics.service.ts` | `common/utils/date-cycle.util.ts`, mobile `dashboard_provider.dart`, `analytics_screen.dart` |
| Insights / logros | `backend/src/modules/insights/insights-generator.service.ts` | `insights.service.ts`, `notification-routing.service.ts`, `jobs/insights-generator.job.ts`, mobile `dashboard_provider.dart`, `achievements_screen.dart` |
| Notificaciones push | `backend/src/common/services/push-notification.service.ts` | `notification-routing.service.ts`, todos los `jobs/*.job.ts`, mobile `fcm_service.dart`, `notification_service.dart` |
| Grupos de gastos compartidos | `backend/src/modules/shared-groups/shared-groups.service.ts` | `shared-expenses.service.ts`, `balances.service.ts`, `settlements.service.ts`, entidades en `entities/`, mobile `shared_groups_provider.dart`, `shared_group_detail_screen.dart` |
| Balances/deudas de grupo | `backend/src/modules/shared-groups/balances.service.ts` | `shared-expense-participant.entity.ts`, `shared-settlement.entity.ts`, mobile `shared_balance_model.dart` |
| Recurrencia de gastos compartidos | `backend/src/jobs/shared-recurring.job.ts` | `shared-expense.entity.ts` (`nextRecurrenceAt`) |
| Recordatorio de deudas | `backend/src/jobs/debt-reminder.job.ts` | `user-notification-preferences.entity.ts` (`debtReminderDays`) |
| Calculadora de préstamos (solo mobile, offline) | mobile `loan_calculator_screen.dart` | — (sin contraparte backend) |
| Routing / navegación mobile | mobile `core/router/app_router.dart` | `app_shell.dart`, `splash_screen.dart`, `auth_provider.dart` |
| Cliente HTTP mobile / refresh de tokens | mobile `core/network/dio_client.dart` | `token_storage.dart`, `api_constants.dart` |
| Migraciones de base de datos | `backend/src/database/migrations/*.ts` | `data-source.ts`, `database.config.ts` |
| Seeds / datos demo | `backend/src/database/seeds/*.ts` | `data-source.ts` |
| Cron jobs (todos) | `backend/src/jobs/*.job.ts` | `app.module.ts` (registro), `push-notification.service.ts` |

---

*Generado a partir de un análisis exhaustivo (6 sub-agentes en paralelo cubriendo backend core/auth/financiero/analytics e insights, y mobile core/auth-home-onboarding-settings-shared/features financieras) sobre ~144 archivos TypeScript y ~61 archivos Dart. Si el código diverge significativamente de este mapa (nuevos módulos, refactors grandes), regenerar las secciones afectadas en lugar de confiar en este documento.*
