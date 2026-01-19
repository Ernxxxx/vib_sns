const functions = require('firebase-functions/v1');

let admin;
let db;

function getAdmin() {
  if (!admin) {
    admin = require('firebase-admin');
    admin.initializeApp();
  }
  return admin;
}

function getDb() {
  if (!db) {
    db = getAdmin().firestore();
  }
  return db;
}

// Helper: delete collection in batches
async function deleteCollection(colRef, batchSize = 500) {
  const query = colRef.limit(batchSize);
  let deleted = 0;
  do {
    const snapshot = await query.get();
    if (snapshot.empty) break;
    const batch = getDb().batch();
    snapshot.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    deleted = snapshot.size;
    console.log(`Deleted batch of ${deleted} from ${colRef.path}`);
  } while (deleted >= batchSize);
}

async function deleteProfileAndReferences(profileId, beaconId = null) {
  const profiles = getDb().collection('profiles');
  const myRef = profiles.doc(profileId);

  // Get the profile data to retrieve username before deletion
  let username = null;
  try {
    const profileSnap = await myRef.get();
    if (profileSnap.exists) {
      const data = profileSnap.data();
      username = data.username || null;
    }
  } catch (e) {
    console.warn('Failed to get profile for username lookup:', e.message);
  }

  // Remove followers/likes entries referencing this profile under other profiles
  const otherProfilesSnap = await profiles.get();
  for (const other of otherProfilesSnap.docs) {
    if (other.id === profileId) continue;
    const followerRef = profiles.doc(other.id).collection('followers').doc(profileId);
    const likeRef = profiles.doc(other.id).collection('likes').doc(profileId);
    try { await followerRef.delete(); } catch (e) { /* ignore */ }
    try { await likeRef.delete(); } catch (e) { /* ignore */ }
  }

  // Delete subcollections under the profile
  try { await deleteCollection(myRef.collection('followers')); } catch (e) { /* ignore */ }
  try { await deleteCollection(myRef.collection('following')); } catch (e) { /* ignore */ }
  try { await deleteCollection(myRef.collection('likes')); } catch (e) { /* ignore */ }

  // Delete streetpass_presences referencing deviceId or beaconId
  try {
    const presencesByDevice = await getDb().collection('streetpass_presences').where('deviceId', '==', profileId).get();
    for (const p of presencesByDevice.docs) { await p.ref.delete(); }
  } catch (e) { /* ignore */ }
  if (beaconId) {
    try {
      const presencesByBeacon = await getDb().collection('streetpass_presences').where('beaconId', '==', beaconId).get();
      for (const p of presencesByBeacon.docs) { await p.ref.delete(); }
    } catch (e) { /* ignore */ }
  }

  // Delete notifications where actorId == profileId (if notifications collection exists)
  try {
    const notifs = await getDb().collection('notifications').where('actorId', '==', profileId).get();
    for (const n of notifs.docs) { await n.ref.delete(); }
  } catch (e) { /* ignore */ }

  // Delete the username from usernames collection
  if (username) {
    try {
      await getDb().collection('usernames').doc(username.toLowerCase()).delete();
      console.log(`Deleted username reservation: ${username}`);
    } catch (e) {
      console.warn('Failed to delete username reservation:', e.message);
    }
  }

  // Finally delete the profile doc itself
  await myRef.delete();
}

exports.deleteUserProfile = functions.https.onCall(async (data, context) => {
  // Only authenticated users can call this
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const uid = context.auth.uid;
  // Allow caller to optionally pass a profileId, but require that the profile
  // belongs to the caller. If not passed, try to find profile with authUid == uid.
  const requestedProfileId = data.profileId || null;
  let targetProfileId = requestedProfileId;
  let beaconId = data.beaconId || null;

  if (!targetProfileId) {
    // Try to find a profile document that has authUid == uid
    const profiles = getDb().collection('profiles');
    const q = await profiles.where('authUid', '==', uid).limit(1).get();
    if (!q.empty) {
      targetProfileId = q.docs[0].id;
    }
  }

  if (!targetProfileId) {
    // As a last resort, allow deletion if a profile doc has id == uid
    const maybe = await getDb().collection('profiles').doc(uid).get();
    if (maybe.exists) {
      targetProfileId = uid;
    }
  }

  if (!targetProfileId) {
    throw new functions.https.HttpsError('not-found', 'No profile found for this authenticated user.');
  }

  // Verify ownership: ensure profile.authUid == uid if authUid field exists
  try {
    const profileSnapshot = await getDb().collection('profiles').doc(targetProfileId).get();
    if (profileSnapshot.exists) {
      const dataSnap = profileSnapshot.data() || {};
      if (dataSnap.authUid && dataSnap.authUid !== uid) {
        throw new functions.https.HttpsError('permission-denied', 'You are not allowed to delete this profile.');
      }
      // If beaconId not provided, try to read it from doc
      if (!beaconId && dataSnap.beaconId) {
        beaconId = dataSnap.beaconId;
      }
    }
  } catch (err) {
    throw new functions.https.HttpsError('internal', 'Failed to validate profile ownership.');
  }

  // Perform deletion
  try {
    await deleteProfileAndReferences(targetProfileId, beaconId);

    // Delete the Firebase Authentication user account
    try {
      await getAdmin().auth().deleteUser(uid);
      console.log(`Successfully deleted Firebase Auth user: ${uid}`);
    } catch (authError) {
      // Log but don't fail the entire operation if Auth deletion fails
      // (e.g., user might already be deleted or have special status)
      console.warn(`Failed to delete Firebase Auth user ${uid}:`, authError.message);
    }

    return { success: true, profileId: targetProfileId, authUserDeleted: true };
  } catch (err) {
    console.error('Deletion failed', err);
    throw new functions.https.HttpsError('internal', 'Failed to delete profile');
  }
});

// ============================================
// FCM Push Notifications
// ============================================

/**
 * Get all FCM tokens for a profile
 * @param {string} profileId
 * @returns {Promise<string[]>}
 */
async function getFcmTokens(profileId) {
  const tokensSnapshot = await getDb()
    .collection('profiles')
    .doc(profileId)
    .collection('fcmTokens')
    .get();

  return tokensSnapshot.docs.map((doc) => doc.data().token).filter(Boolean);
}

/**
 * Check if push notifications are enabled for a profile
 * @param {string} profileId
 * @returns {Promise<boolean>}
 */
async function isPushEnabled(profileId) {
  try {
    const profileDoc = await getDb().collection('profiles').doc(profileId).get();
    if (!profileDoc.exists) return false;
    const data = profileDoc.data();
    // Default to enabled if field doesn't exist
    return data.pushNotificationsEnabled !== false;
  } catch (e) {
    console.error('Error checking push settings:', e);
    return true; // Default to enabled on error
  }
}

/**
 * Send push notification and clean up invalid tokens
 * @param {string} profileId - Target user's profile ID
 * @param {object} payload - FCM message payload
 */
async function sendPushNotification(profileId, payload) {
  // Check if push is enabled
  const enabled = await isPushEnabled(profileId);
  if (!enabled) {
    console.log(`Push notifications disabled for ${profileId}`);
    return;
  }

  const tokens = await getFcmTokens(profileId);
  if (tokens.length === 0) {
    console.log(`No FCM tokens for ${profileId}`);
    return;
  }

  const messaging = getAdmin().messaging();
  const invalidTokens = [];

  for (const token of tokens) {
    try {
      await messaging.send({
        token,
        ...payload,
      });
      console.log(`Sent notification to ${profileId}`);
    } catch (error) {
      console.error(`Failed to send to token: ${error.code}`);
      // Clean up invalid tokens
      if (
        error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(token);
      }
    }
  }

  // Delete invalid tokens
  for (const invalidToken of invalidTokens) {
    const tokenHash = Math.abs(invalidToken.hashCode?.() || invalidToken.split('').reduce((a, b) => ((a << 5) - a + b.charCodeAt(0)) | 0, 0)).toString();
    try {
      await getDb()
        .collection('profiles')
        .doc(profileId)
        .collection('fcmTokens')
        .doc(tokenHash)
        .delete();
      console.log(`Deleted invalid token for ${profileId}`);
    } catch (e) {
      console.error('Error deleting token:', e);
    }
  }
}

/**
 * Get profile display name by profileId
 */
async function getDisplayName(profileId) {
  try {
    const doc = await getDb().collection('profiles').doc(profileId).get();
    return doc.exists ? doc.data().displayName || 'ユーザー' : 'ユーザー';
  } catch {
    return 'ユーザー';
  }
}

/**
 * Get profile display name by authUid
 * Searches for a profile where authUid matches
 */
async function getDisplayNameByAuthUid(authUid) {
  try {
    // First try to find profile by authUid field
    const query = await getDb().collection('profiles')
      .where('authUid', '==', authUid)
      .limit(1)
      .get();

    if (!query.empty) {
      const data = query.docs[0].data();
      return data.displayName || 'ユーザー';
    }

    // Fallback: check if authUid is also the profileId
    const doc = await getDb().collection('profiles').doc(authUid).get();
    return doc.exists ? doc.data().displayName || 'ユーザー' : 'ユーザー';
  } catch {
    return 'ユーザー';
  }
}

/**
 * Get profile ID and display name from document data or by authUid lookup
 */
async function getProfileInfoFromDoc(docData, authUid) {
  // Try to get info from embedded profile data first
  const profileData = docData?.profile;
  if (profileData) {
    const displayName = profileData.displayName;
    const profileId = docData.viewerProfileId || profileData.id || authUid;
    if (displayName && displayName.trim() !== '' && displayName !== 'Unknown') {
      return { displayName, profileId };
    }
  }

  // Fall back to viewerProfileId if available
  const viewerProfileId = docData?.viewerProfileId;
  if (viewerProfileId) {
    const name = await getDisplayName(viewerProfileId);
    return { displayName: name, profileId: viewerProfileId };
  }

  // Last resort: search by authUid
  const name = await getDisplayNameByAuthUid(authUid);
  return { displayName: name, profileId: authUid };
}

// ============================================
// FCM Triggers
// ============================================

/**
 * Trigger: New follower
 * Path: profiles/{targetId}/followers/{followerId}
 * Note: followerId is actually authUid (Firebase Auth UID)
 */
exports.onFollow = functions.firestore
  .document('profiles/{targetId}/followers/{followerId}')
  .onCreate(async (snap, context) => {
    const { targetId, followerId } = context.params;
    const data = snap.data();

    // Get profile info from document data or by lookup
    const { displayName: followerName, profileId } = await getProfileInfoFromDoc(data, followerId);

    // Don't notify yourself
    if (targetId === profileId || targetId === followerId) return null;

    await sendPushNotification(targetId, {
      notification: {
        title: '新しいフォロワー',
        body: `${followerName}さんがあなたをフォローしました`,
      },
      data: {
        type: 'follow',
        profileId: profileId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    });

    return null;
  });

/**
 * Trigger: Profile like
 * Path: profiles/{targetId}/likes/{likerId}
 * Note: likerId is actually authUid (Firebase Auth UID)
 */
exports.onLike = functions.firestore
  .document('profiles/{targetId}/likes/{likerId}')
  .onCreate(async (snap, context) => {
    const { targetId, likerId } = context.params;
    const data = snap.data();

    // Get profile info from document data or by lookup
    const { displayName: likerName, profileId } = await getProfileInfoFromDoc(data, likerId);

    // Don't notify yourself
    if (targetId === profileId || targetId === likerId) return null;

    await sendPushNotification(targetId, {
      notification: {
        title: 'いいね',
        body: `${likerName}さんがあなたにいいねしました`,
      },
      data: {
        type: 'like',
        profileId: profileId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    });

    return null;
  });

/**
 * Trigger: Timeline post like
 * Path: timelinePosts/{postId}
 * Detects new likes by comparing likedBy array
 */
exports.onTimelineLike = functions.firestore
  .document('timelinePosts/{postId}')
  .onUpdate(async (change, context) => {
    const { postId } = context.params;
    const before = change.before.data();
    const after = change.after.data();

    const beforeLikes = before.likedBy || [];
    const afterLikes = after.likedBy || [];

    // Find new likes only
    const newLikes = afterLikes.filter((id) => !beforeLikes.includes(id));
    if (newLikes.length === 0) return null;

    const authorId = after.authorId;
    const caption = after.caption || '投稿';
    const snippet = caption.length > 20 ? caption.substring(0, 20) + '...' : caption;

    for (const likerId of newLikes) {
      // Don't notify yourself
      if (likerId === authorId) continue;

      // likedBy contains profileId, so try that first, then fall back to authUid lookup
      let likerName = await getDisplayName(likerId);
      if (likerName === 'ユーザー') {
        likerName = await getDisplayNameByAuthUid(likerId);
      }

      await sendPushNotification(authorId, {
        notification: {
          title: 'いいね',
          body: `${likerName}さんが「${snippet}」にいいねしました`,
        },
        data: {
          type: 'timelineLike',
          postId: postId,
          profileId: likerId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      });
    }

    return null;
  });

/**
 * Trigger: Reply notification
 * Path: profiles/{targetId}/notifications/{notificationId}
 * Only processes type='reply'
 */
exports.onReplyNotification = functions.firestore
  .document('profiles/{targetId}/notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const { targetId } = context.params;
    const data = snap.data();

    // Only process reply notifications
    if (data.type !== 'reply') return null;

    // Dart code saves as 'fromUserName', not 'replierName'
    const replierName = data.fromUserName || data.replierName || 'ユーザー';
    const caption = data.caption || '返信';
    const snippet = caption.length > 30 ? caption.substring(0, 30) + '...' : caption;

    await sendPushNotification(targetId, {
      notification: {
        title: `${replierName}さんからの返信`,
        body: snippet,
      },
      data: {
        type: 'reply',
        postId: data.postId || '',
        replyId: data.replyId || '',
        profileId: data.fromUserId || data.replierProfileId || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    });

    return null;
  });

/**
 * Trigger: New DM message
 * Path: conversations/{conversationId}/messages/{messageId}
 */
exports.onDM = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const { conversationId } = context.params;
    const message = snap.data();
    const senderId = message.senderId;
    const recipientId = message.recipientId;

    // Don't notify the sender
    if (!recipientId || senderId === recipientId) return null;

    // senderId is profileId in DM messages
    let senderName = await getDisplayName(senderId);
    if (senderName === 'ユーザー') {
      senderName = await getDisplayNameByAuthUid(senderId);
    }
    const isImage = message.type === 'image';
    const bodyText = isImage ? '📷 画像を送信しました' : (message.text || 'メッセージを送信しました');
    const snippet = bodyText.length > 30 ? bodyText.substring(0, 30) + '...' : bodyText;

    await sendPushNotification(recipientId, {
      notification: {
        title: `${senderName}さんからのメッセージ`,
        body: snippet,
      },
      data: {
        type: 'dm',
        conversationId: conversationId,
        messageId: context.params.messageId,
        profileId: senderId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    });

    return null;
  });

/**
 * Trigger: Encounter notification (streetpass)
 * Path: profiles/{targetId}/notifications/{notificationId}
 * Only processes type='encounter'
 */
exports.onEncounterNotification = functions.firestore
  .document('profiles/{targetId}/notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const { targetId } = context.params;
    const data = snap.data();

    // Only process encounter notifications
    if (data.type !== 'encounter') return null;

    const encounterName = data.fromUserName || 'ユーザー';
    const fromUserId = data.fromUserId || '';
    const isRepeat = data.isRepeat === true;
    const isReunion = data.isReunion === true;

    const title = isReunion
      ? '再会しました'
      : (isRepeat ? 'またすれ違いました' : 'すれ違いました');
    const body = `${encounterName}さんと${isRepeat ? 'また' : ''}すれ違いました`;

    // Use collapseKey to prevent duplicate notifications from the same person.
    // When a new notification with the same collapseKey arrives, it replaces the old one.
    const collapseKey = fromUserId ? `encounter_${fromUserId}` : undefined;

    await sendPushNotification(targetId, {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: 'encounter',
        profileId: fromUserId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: collapseKey ? {
        collapseKey: collapseKey,
      } : undefined,
      apns: collapseKey ? {
        headers: {
          'apns-collapse-id': collapseKey,
        },
      } : undefined,
    });

    return null;
  });
