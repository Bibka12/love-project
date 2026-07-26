importScripts(
  "https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js"
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js"
);

firebase.initializeApp({
  apiKey: "AIzaSyCYciw7by-YNLxlhF93Y1zaahM3gDXfh0Q",
  authDomain: "love-project-nb-2026.firebaseapp.com",
  projectId: "love-project-nb-2026",
  storageBucket: "love-project-nb-2026.firebasestorage.app",
  messagingSenderId: "1089370373503",
  appId: "1:1089370373503:web:67e13d16b91df275d12e4a",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  // Сообщения с notification-полем Firebase показывает автоматически.
  // Этот обработчик оставлен для data-only уведомлений.
  if (message.notification) return;

  const data = message.data || {};
  const title = data.title || "N❤️B";
  const options = {
    body: data.body || "Новое уведомление",
    icon: "icons/Icon-192.png",
    badge: "icons/Icon-192.png",
    tag: data.tag || data.type || "love-project-notification",
    data,
  };

  self.registration.showNotification(title, options);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((windowClients) => {
        for (const client of windowClients) {
          if ("focus" in client) return client.focus();
        }
        return clients.openWindow("./");
      })
  );
});
