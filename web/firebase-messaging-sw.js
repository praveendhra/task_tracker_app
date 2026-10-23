// Shows push reminders while Task Tracker isn't open, and opens the app when
// one is clicked. Firebase looks for this file at the site root.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCBB2jYY_EZBlyOgvIp84Eso54ieXknVKE',
  appId: '1:7054745973:web:32ff9c1faaeabe8224733c',
  messagingSenderId: '7054745973',
  projectId: 'task-tracker-9c52d',
  authDomain: 'task-tracker-9c52d.firebaseapp.com',
  storageBucket: 'task-tracker-9c52d.appspot.com',
});

// Notification messages are displayed by the SDK; this just makes sure a click
// focuses an open tab instead of opening a new one.
firebase.messaging();

self.addEventListener('notificationclick', (event) => {
  const link = event.notification?.data?.FCM_MSG?.notification?.click_action
    || event.notification?.data?.FCM_MSG?.fcmOptions?.link
    || self.registration.scope;
  event.notification.close();
  event.waitUntil((async () => {
    const all = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of all) {
      if (c.url.startsWith(self.registration.scope) && 'focus' in c) return c.focus();
    }
    return clients.openWindow(link);
  })());
});
