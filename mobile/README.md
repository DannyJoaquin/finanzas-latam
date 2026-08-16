# Zentri

Aplicacion Flutter para finanzas personales. El mismo proyecto mantiene los
targets Android/iOS y una salida Web instalable como PWA.

## Desarrollo Web

Desde esta carpeta:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

El backend local debe estar disponible en `http://localhost:3000`. Si Docker
Desktop esta iniciado, puede levantarse desde la raiz del repositorio con:

```powershell
docker compose up --build
```

## Build De Produccion

La PWA debe usar una API HTTPS accesible desde el dominio donde se publique:

```powershell
flutter build web --release --no-wasm-dry-run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

El hosting debe servir `build/web` por HTTPS y redirigir las rutas de Flutter
a `index.html`. El backend debe incluir el origen exacto de la PWA en
`ALLOWED_ORIGINS`, separado por comas si hay mas de un dominio.

## Firebase Web Y FCM

Firebase Web es opcional en desarrollo. Para activar FCM, agrega los defines
de configuracion al comando de build o run:

```powershell
flutter build web --release --no-wasm-dry-run `
	--dart-define=API_BASE_URL=https://api.example.com/api/v1 `
	--dart-define=FIREBASE_WEB_API_KEY=... `
	--dart-define=FIREBASE_WEB_APP_ID=... `
	--dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID=... `
	--dart-define=FIREBASE_WEB_PROJECT_ID=... `
	--dart-define=FIREBASE_WEB_AUTH_DOMAIN=... `
	--dart-define=FIREBASE_WEB_STORAGE_BUCKET=... `
	--dart-define=FIREBASE_WEB_VAPID_KEY=...
```

No agregues esos valores a Git. Antes de desplegar FCM, reemplaza los cuatro
placeholders `__FIREBASE_WEB_*__` de `web/firebase-messaging-sw.js` con los
mismos valores publicos del proyecto Firebase. El service worker necesita
HTTPS, el dominio autorizado en Firebase y una clave VAPID para obtener el
token Web.

## Login Con Google
El login con Google usa un OAuth client de tipo Web. El ID que aparece en la
captura como **ID de cliente para Android** no sirve para la PWA y no muestra
la opcion de origenes JavaScript. En Google Cloud Console vuelve a **Clientes**
y crea un cliente de tipo **Aplicacion web**. En ese cliente agrega todos los
origenes exactos que usaras:

```text
http://localhost:8092
https://app.example.com
```

No agregues `/#/login` ni otras rutas. Usa el ID del cliente Web, no el ID
Android, tanto al compilar la PWA como al configurar el backend.

Para desarrollo, compila la PWA con el client ID Web:

```powershell
flutter build web --release --no-wasm-dry-run `
	--dart-define=API_BASE_URL=https://api.example.com/api/v1 `
	--dart-define=GOOGLE_WEB_CLIENT_ID=CLIENT_ID.apps.googleusercontent.com
```

En Google Cloud Console, agrega el origen exacto de desarrollo (por ejemplo,
`http://localhost:8082`) y el origen HTTPS de produccion en el OAuth client
Web. El backend debe usar ese mismo valor en `GOOGLE_CLIENT_ID`. Docker Compose
lee esa variable del entorno y ya no contiene un ID Android fijo:

```powershell
$env:GOOGLE_CLIENT_ID = 'CLIENT_ID_WEB.apps.googleusercontent.com'
docker compose up --build
```

Para produccion, configura `GOOGLE_CLIENT_ID` en el entorno del backend y usa
el mismo valor en `GOOGLE_WEB_CLIENT_ID` al generar `build/web`. El dominio
HTTPS de produccion debe estar registrado como origen JavaScript en el mismo
cliente Web.

## Instalacion En IPhone

1. Abre la URL HTTPS de la PWA en Safari.
2. Pulsa **Compartir**.
3. Selecciona **Agregar a pantalla de inicio**.
4. Confirma con **Agregar** y abre Zentri desde el nuevo icono.

El modo standalone depende de la instalacion desde Safari; abrir la URL en una
pestana normal no activa ese modo.

## Compatibilidad Y Limites Web

- Hive conserva preferencias y estado de onboarding en el almacenamiento Web.
- `flutter_secure_storage` usa el backend Web del navegador, que no ofrece la
	misma garantia de aislamiento que Keychain o Keystore nativos.
- Las alertas locales programadas de corte y pago de tarjetas siguen siendo
	nativas. En Web se soportan notificaciones de primer plano mediante la API
	del navegador y FCM puede mostrar notificaciones en segundo plano cuando se
	configura el service worker.
- En Web, el permiso de notificaciones se solicita de forma explicita desde
	Ajustes > Notificaciones > Activar. Las notificaciones de primer plano y de
	fondo conservan su ruta al pulsarlas.
- El service worker cachea el shell de la aplicacion y usa la red primero para
	los recursos visitados. Esto permite abrir la interfaz despues de una visita
	previa, pero no convierte la API ni la autenticacion en un sistema offline
	first; las operaciones y la sincronizacion requieren conectividad.
- Google Sign-In Web necesita un OAuth client de tipo Web con el dominio de la
	PWA autorizado.
- PDF y compartir archivos dependen de las capacidades del navegador; el PDF
	se genera en memoria para evitar `dart:io` y `path_provider`.
