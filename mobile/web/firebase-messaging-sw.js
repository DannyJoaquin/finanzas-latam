'use strict';

// This worker serves two purposes: FCM background notifications and a
// network-first cache for the static Flutter shell. It never caches API data.
const APP_ROOT = new URL('/', self.location.origin);
const CACHE_NAME = 'zentri-shell-v1';
const SHELL_ASSETS = [
  appUrl(''),
  appUrl('index.html'),
  appUrl('manifest.json'),
  appUrl('favicon.png'),
  appUrl('flutter_bootstrap.js'),
  appUrl('icons/Icon-192.png'),
  appUrl('icons/Icon-512.png'),
  appUrl('icons/Icon-maskable-192.png'),
  appUrl('icons/Icon-maskable-512.png'),
];

function appUrl(path) {
  return new URL(path, APP_ROOT).toString();
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(SHELL_ASSETS))
      .catch((error) => {
        // A partial install should not prevent the app from loading online.
        console.warn('Zentri shell cache skipped:', error);
      })
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((key) => key.startsWith('zentri-shell-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key)),
      ))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (
    request.method !== 'GET' ||
    url.origin !== self.location.origin ||
    url.pathname.endsWith('/firebase-messaging-sw.js') ||
    url.pathname.endsWith('/flutter_service_worker.js')
  ) {
    return;
  }

  // API calls normally live on api.zentri.tech and are cross-origin. Keep
  // this guard as a second line of defense if the API is ever proxied here.
  if (url.pathname.startsWith('/api/')) return;

  event.respondWith(networkFirst(request));
});

async function networkFirst(request) {
  const cache = await caches.open(CACHE_NAME);

  try {
    const response = await fetch(request);
    if (response.ok && response.type === 'basic') {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached = await cache.match(request);
    if (cached) return cached;

    if (request.mode === 'navigate') {
      const shell = await cache.match(appUrl('index.html'));
      if (shell) return shell;
    }

    throw error;
  }
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = new URL(
    `#${routeForNotification(event.notification.data || {})}`,
    appUrl(''),
  ).toString();

  event.waitUntil((async () => {
    const clients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    const existingClient = clients.find((client) => 'focus' in client);

    if (existingClient) {
      if ('navigate' in existingClient && existingClient.url !== targetUrl) {
        await existingClient.navigate(targetUrl);
      }
      await existingClient.focus();
      return;
    }

    await self.clients.openWindow(targetUrl);
  })());
});

function routeForNotification(data) {
  switch (data.type) {
    case 'budget_alert':
      return '/budgets';
    case 'weekly_summary':
      return '/analytics';
    case 'insight':
      return '/home';
    default:
      return '/home';
  }
}

const firebaseConfig = {
  apiKey: '__FIREBASE_WEB_API_KEY__',
  appId: '__FIREBASE_WEB_APP_ID__',
  messagingSenderId: '__FIREBASE_WEB_MESSAGING_SENDER_ID__',
  projectId: '__FIREBASE_WEB_PROJECT_ID__',
};

const requiredConfig = [
  firebaseConfig.apiKey,
  firebaseConfig.appId,
  firebaseConfig.messagingSenderId,
  firebaseConfig.projectId,
];

const isConfigured = requiredConfig.every(
  (value) => value && !value.startsWith('__'),
);

if (isConfigured) {
  importScripts(
    'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
    'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
  );

  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification || {};
    const title = notification.title || 'Nueva alerta';
    const options = {
      body: notification.body || 'Tienes una nueva notificacion',
      icon: appUrl('icons/Icon-192.png'),
      badge: appUrl('icons/Icon-192.png'),
      data: payload.data || {},
    };

    self.registration.showNotification(title, options);
  });
}