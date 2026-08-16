'use strict';

const APP_ROOT = new URL('./', self.location.href);

function appUrl(path) {
  return new URL(path, APP_ROOT).toString();
}

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((key) => key.startsWith('zentri-app-shell-'))
          .map((key) => caches.delete(key)),
      ))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;
  event.respondWith(fetch(request));
});

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