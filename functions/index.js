// Deploy Trigger: 2026-06-07T17:50:00Z - Precision Timing Updates
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");

// Initialize with a specific app name to avoid instance conflicts
const app = admin.initializeApp();
const db = getFirestore(app, "talktandem");

/**
 * 1. PREMIUM SECURITY SWEEPER
 */
exports.sweepExpiredPremiums = functions.region("asia-south1")
    .pubsub.schedule("every 6 hours").onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        const expiredQuery = db.collection("users").where("premiumExpiresAt", "<", now);
        const snapshot = await expiredQuery.get();
        if (snapshot.empty) return null;

        const batch = db.batch();
        let hasUpdates = false;
        snapshot.forEach((doc) => {
            const data = doc.data();
            if (data.isPremium === true || data.premiumStatus === "active") {
                batch.update(doc.ref, {
                    isPremium: false,
                    premiumStatus: "expired",
                });
                hasUpdates = true;
            }
        });

        if (!hasUpdates) return null;
        return batch.commit();
    });

/**
 * 2. 5-MINUTE AUTO OFFLINE SWEEPER
 */
exports.enforceOnlineStatus = functions.region("asia-south1")
    .pubsub.schedule("every 5 minutes").onRun(async (context) => {
        const fiveMinutesAgo = new Date(Date.now() - 5 * 60000);
        const staleTimestamp = admin.firestore.Timestamp.fromDate(fiveMinutesAgo);
        const staleQuery = db.collection("users").where("isOnline", "==", true).where("lastActive", "<", staleTimestamp);

        const snapshot = await staleQuery.get();
        if (snapshot.empty) return null;

        const batch = db.batch();
        snapshot.forEach((doc) => {
            batch.update(doc.ref, {
                isOnline: false,
            });
        });
        return batch.commit();
    });

/**
 * 3. SECURE PREMIUM ACTIVATION
 */
exports.activatePremium = functions.region("asia-south1")
    .https.onCall(async (data, context) => {
        if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const planId = data.planId;
        let userPhone = context.auth.token.phone_number;

        // Fallback for resolving userPhone via UID if phone token is missing
        if (!userPhone) {
            const uq = await db.collection("users").where("uid", "==", context.auth.uid).limit(1).get();
            if (!uq.empty) userPhone = uq.docs[0].id;
        }
        if (!userPhone) throw new functions.https.HttpsError("invalid-argument", "No phone number");

        const now = new Date();
        let expiresAt;
        if (planId === "1_month") {
            expiresAt = new Date(now.setMonth(now.getMonth() + 1));
        } else if (planId === "3_months") {
            expiresAt = new Date(now.setMonth(now.getMonth() + 3));
        } else {
            expiresAt = new Date(now.setFullYear(now.getFullYear() + 1));
        }

        await db.collection("users").doc(userPhone).update({
            isPremium: true,
            premiumPlan: planId,
            premiumPurchasedAt: admin.firestore.Timestamp.now(),
            premiumExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            premiumStatus: "active",
        });

        return { success: true };
    });

/**
 * 4. SECURE CALL SESSION PROCESSING (NEW)
 */
exports.endCallSession = functions.region("asia-south1")
    .https.onCall(async (data, context) => {
        if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const { callId, durationSeconds, dateStr } = data;
        let userPhone = context.auth.token.phone_number;

        if (!userPhone) {
            const uq = await db.collection("users").where("uid", "==", context.auth.uid).limit(1).get();
            if (!uq.empty) userPhone = uq.docs[0].id;
        }

        if (!userPhone || !callId) throw new functions.https.HttpsError("invalid-argument", "Missing params");

        return await db.runTransaction(async (transaction) => {
            const callRef = db.collection("calls").doc(callId);
            const userRef = db.collection("users").doc(userPhone);
            const practiceHistoryRef = db.collection("users").doc(userPhone).collection("practice_history").doc(dateStr);

            // Execute all reads first
            const callDoc = await transaction.get(callRef);
            const userDoc = await transaction.get(userRef);
            const practiceDoc = await transaction.get(practiceHistoryRef);

            if (!callDoc.exists) return { coinsEarned: 0, success: false, reason: "Call not found" };

            const callData = callDoc.data();
            
            // Calculate coins securely
            const coinsEarned = durationSeconds >= 60 ? Math.floor(durationSeconds / 60) * 2 : 1;

            // Safe-guard: Use existing startedAt or default to now to prevent "undefined" error
            const startedAt = callData.startedAt || admin.firestore.Timestamp.now();

            let newTodayCalls = 1;
            let newDailyTalkSeconds = durationSeconds || 0;
            let newDailyCallsCount = 1;
            let currentTotalSeconds = 0;

            if (userDoc.exists) {
                const userData = userDoc.data() || {};
                currentTotalSeconds = userData.totalTalkSeconds || (userData.minutesPracticed || 0) * 60;
                const dbLastCallDate = userData.lastCallDate;
                if (dbLastCallDate === dateStr) {
                    newTodayCalls = ((userData.todayCalls || 0) * 1) + 1;
                    newDailyTalkSeconds = ((userData.dailyTalkSeconds || 0) * 1) + (durationSeconds || 0);
                    newDailyCallsCount = ((userData.dailyCallsCount || 0) * 1) + 1;
                }
            }

            const newTodayMinutes = Math.floor(newDailyTalkSeconds / 60);
            const newTotalSeconds = currentTotalSeconds + (durationSeconds || 0);
            const newMinutesPracticed = Math.floor(newTotalSeconds / 60);

            let currentSeconds = 0;
            if (practiceDoc.exists) {
                currentSeconds = practiceDoc.data().seconds || (practiceDoc.data().minutes || 0) * 60;
            }
            const newSeconds = currentSeconds + (durationSeconds || 0);
            const newMinutes = Math.floor(newSeconds / 60);

            // Execute all writes last
            transaction.update(userRef, {
                coins: admin.firestore.FieldValue.increment(coinsEarned),
                totalTalkSeconds: newTotalSeconds,
                minutesPracticed: newMinutesPracticed,
                totalCalls: admin.firestore.FieldValue.increment(1),
                lastCallDate: dateStr,
                todayCalls: newTodayCalls,
                todayMinutes: newTodayMinutes,
                dailyTalkSeconds: newDailyTalkSeconds,
                dailyCallsCount: newDailyCallsCount,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            transaction.set(practiceHistoryRef, {
                date: dateStr,
                seconds: newSeconds,
                minutes: newMinutes,
                calls: admin.firestore.FieldValue.increment(1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            // Update call status and history
            transaction.update(callRef, {
                status: "ended",
                endedAt: admin.firestore.FieldValue.serverTimestamp(),
                startedAt: startedAt, // Ensuring this is defined
            });

            return { coinsEarned: coinsEarned };
        });
    });

exports.endAiCallSession = functions.region("asia-south1")
    .https.onCall(async (data, context) => {
        if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const { durationSeconds, coinsEarned, dateStr } = data;
        let userPhone = context.auth.token.phone_number;

        if (!userPhone) {
            const uq = await db.collection("users").where("uid", "==", context.auth.uid).limit(1).get();
            if (!uq.empty) userPhone = uq.docs[0].id;
        }

        if (!userPhone) throw new functions.https.HttpsError("invalid-argument", "No phone number found");

        return await db.runTransaction(async (transaction) => {
            const userRef = db.collection("users").doc(userPhone);
            const practiceHistoryRef = db.collection("users").doc(userPhone).collection("practice_history").doc(dateStr);

            // Execute all reads first
            const userDoc = await transaction.get(userRef);
            const practiceDoc = await transaction.get(practiceHistoryRef);

            let newTodayCalls = 1;
            let newDailyTalkSeconds = durationSeconds || 0;
            let newDailyCallsCount = 1;
            let currentTotalSeconds = 0;

            if (userDoc.exists) {
                const userData = userDoc.data() || {};
                currentTotalSeconds = userData.totalTalkSeconds || (userData.minutesPracticed || 0) * 60;
                const dbLastCallDate = userData.lastCallDate;
                if (dbLastCallDate === dateStr) {
                    newTodayCalls = ((userData.todayCalls || 0) * 1) + 1;
                    newDailyTalkSeconds = ((userData.dailyTalkSeconds || 0) * 1) + (durationSeconds || 0);
                    newDailyCallsCount = ((userData.dailyCallsCount || 0) * 1) + 1;
                }
            }

            const newTodayMinutes = Math.floor(newDailyTalkSeconds / 60);
            const newTotalSeconds = currentTotalSeconds + (durationSeconds || 0);
            const newMinutesPracticed = Math.floor(newTotalSeconds / 60);

            let currentSeconds = 0;
            if (practiceDoc.exists) {
                currentSeconds = practiceDoc.data().seconds || (practiceDoc.data().minutes || 0) * 60;
            }
            const newSeconds = currentSeconds + (durationSeconds || 0);
            const newMinutes = Math.floor(newSeconds / 60);

            // Execute all writes last
            transaction.update(userRef, {
                coins: admin.firestore.FieldValue.increment(coinsEarned || 0),
                totalTalkSeconds: newTotalSeconds,
                minutesPracticed: newMinutesPracticed,
                totalCalls: admin.firestore.FieldValue.increment(1),
                lastCallDate: dateStr,
                todayCalls: newTodayCalls,
                todayMinutes: newTodayMinutes,
                dailyTalkSeconds: newDailyTalkSeconds,
                dailyCallsCount: newDailyCallsCount,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            transaction.set(practiceHistoryRef, {
                date: dateStr,
                seconds: newSeconds,
                minutes: newMinutes,
                calls: admin.firestore.FieldValue.increment(1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            return { success: true };
        });
    });


/**
 * 5. SECURE CALL FEEDBACK & BONUS COINS (NEW)
 */
exports.submitCallFeedback = functions.region("asia-south1")
    .https.onCall(async (data, context) => {
        if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const { callId, ratedUserId, rating, tags } = data;
        const raterId = context.auth.uid;
        let userPhone = context.auth.token.phone_number;

        if (!userPhone) {
            const uq = await db.collection("users").where("uid", "==", context.auth.uid).limit(1).get();
            if (!uq.empty) userPhone = uq.docs[0].id;
        }

        if (!callId || !ratedUserId || !rating) throw new functions.https.HttpsError("invalid-argument", "Missing params");

        // Save Feedback
        await db.collection("call_feedback").add({
            callId, raterId, ratedUserId, rating, tags, createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Atomic Transaction: Update Peer's Rating 
        await db.runTransaction(async (t) => {
            const peerRef = db.collection("users").doc(ratedUserId);
            const peerDoc = await t.get(peerRef);
            if (peerDoc.exists) {
                const pData = peerDoc.data();
                const oldAvg = pData.avgRating != null ? pData.avgRating : 5.0;
                const ratingCount = pData.ratingsCount != null ? pData.ratingsCount : 0;
                const newCount = ratingCount + 1;
                const newAvg = ((oldAvg * ratingCount) + rating) / newCount;
                t.update(peerRef, {
                    avgRating: parseFloat(newAvg.toFixed(1)),
                    ratingsCount: newCount,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }
        });

        // Grant 25 Bonus Coins securely
        if (userPhone) {
            await db.collection("users").doc(userPhone).update({
                coins: admin.firestore.FieldValue.increment(25),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        return { success: true };
    });