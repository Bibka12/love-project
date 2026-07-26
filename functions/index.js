const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

function messagePreview(message) {
  if (message.type === "image") return "📷 Фотография";
  if (message.type === "voice") return "🎤 Голосовое сообщение";
  const text = String(message.text || "").trim();
  return text.length > 120 ? `${text.substring(0, 117)}...` : text;
}

async function readTokens(uid) {
  if (!uid) return [];
  const snapshot = await db.collection("users").doc(uid).get();
  const rawTokens = snapshot.data()?.fcmTokens;
  if (!Array.isArray(rawTokens)) return [];
  return [...new Set(rawTokens.filter((token) => typeof token === "string"))];
}

async function removeInvalidTokens(uid, responses, tokens) {
  const invalidCodes = new Set([
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token",
  ]);

  const invalidTokens = [];
  responses.forEach((response, index) => {
    if (!response.success && invalidCodes.has(response.error?.code)) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length === 0) return;
  await db.collection("users").doc(uid).set(
    {
      fcmTokens: FieldValue.arrayRemove(...invalidTokens),
      notificationsUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function sendToUser({ uid, title, body, data, tag }) {
  const tokens = await readTokens(uid);
  if (tokens.length === 0) {
    logger.info("No notification tokens", { uid, type: data.type });
    return;
  }

  const result = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: {
      priority: "high",
      notification: {
        sound: "default",
        tag,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    webpush: {
      headers: {
        Urgency: "high",
      },
      notification: {
        icon: "/icons/Icon-192.png",
        badge: "/icons/Icon-192.png",
        tag,
      },
    },
  });

  await removeInvalidTokens(uid, result.responses, tokens);
  logger.info("Notification sent", {
    uid,
    type: data.type,
    successCount: result.successCount,
    failureCount: result.failureCount,
  });
}

exports.notifyNewMessage = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "europe-west1",
  },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    // Запись истории звонка уже имеет отдельное уведомление.
    if (String(event.params.messageId).startsWith("call_")) return;

    const receiverUid = String(message.receiverUid || "");
    const senderUid = String(message.senderUid || "");
    if (!receiverUid || receiverUid === senderUid) return;

    const sender = await db.collection("users").doc(senderUid).get();
    const senderData = sender.data() || {};
    const senderName = String(
      senderData.name || senderData.displayName || "Новое сообщение"
    );

    await sendToUser({
      uid: receiverUid,
      title: senderName,
      body: messagePreview(message) || "Новое сообщение",
      tag: `chat_${event.params.chatId}`,
      data: {
        type: "chat",
        chatId: String(event.params.chatId),
        messageId: String(event.params.messageId),
        senderUid,
        senderName,
      },
    });
  }
);

exports.notifyIncomingCall = onDocumentCreated(
  {
    document: "calls/{callId}",
    region: "europe-west1",
  },
  async (event) => {
    const call = event.data?.data();
    if (!call || call.status !== "ringing") return;

    const receiverUid = String(call.receiverUid || "");
    const callerUid = String(call.callerUid || "");
    if (!receiverUid || receiverUid === callerUid) return;

    const isVideo = call.type === "video";
    const callerName = String(call.callerName || "Пользователь");

    await sendToUser({
      uid: receiverUid,
      title: callerName,
      body: isVideo ? "Входящий видеозвонок" : "Входящий звонок",
      tag: `call_${event.params.callId}`,
      data: {
        type: "call",
        callId: String(event.params.callId),
        callType: isVideo ? "video" : "audio",
        callerUid,
        callerName,
        callerPhotoUrl: String(call.callerPhotoUrl || ""),
      },
    });
  }
);
