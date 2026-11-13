// Service worker for Firebase Cloud Messaging on the web build.
//
// Shows booking pushes while the app tab is closed or in the background
// (in the foreground the app shows its own in-app banner instead).
//
// SETUP: after `flutterfire configure`, copy the web app's values from
// lib/firebase_options.dart (DefaultFirebaseOptions.web) into firebaseConfig
// below. Web push also needs the VAPID key at build time:
//   flutter build web --dart-define=FCM_VAPID_KEY=<key>
// Until the config is filled in, this worker does nothing.

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: 'REPLACE_ME',
  appId: 'REPLACE_ME',
  messagingSenderId: 'REPLACE_ME',
  projectId: 'REPLACE_ME',
  authDomain: 'REPLACE_ME',
  storageBucket: 'REPLACE_ME',
};

if (firebaseConfig.apiKey !== 'REPLACE_ME') {
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();

  // Messages with a `notification` block (what the notifications Cloud
  // Functions send) are displayed by the SDK automatically. Data-only
  // messages are shown here.
  messaging.onBackgroundMessage((payload) => {
    if (payload.notification) return;
    const data = payload.data || {};
    if (!data.title) return;
    self.registration.showNotification(data.title, {
      body: data.body || '',
      icon: 'icons/Icon-192.png',
      data,
    });
  });
}

// Tapping a notification focuses (or opens) the app.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const w of windows) {
        if ('focus' in w) return w.focus();
      }
      return clients.openWindow('./');
    }),
  );
});
