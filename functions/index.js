const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Scheduled function: Runs every day at 9:30 AM IST (3:00 AM UTC)
exports.sendDailyNotifications = functions.pubsub
    .schedule('0 3 * * *') // 3:00 AM UTC = 9:30 AM IST+1 (considering DST)
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        console.log('Starting daily good morning notifications at', new Date().toISOString());

        try {
            // Get all users who have FCM tokens
            const usersSnapshot = await admin.firestore()
                .collection('users-fcm-tokens')
                .get();

            const userIds = [...new Set(usersSnapshot.docs.map(doc => doc.data().userId))];

            console.log(`Found ${userIds.length} users to notify`);

            let goodMorningCount = 0;

            // Send good morning message to each user
            for (const userId of userIds) {
                try {
                    await sendGoodMorningMessage(userId);
                    goodMorningCount++;
                } catch (error) {
                    console.error(`Error sending good morning to user ${userId}:`, error);
                }
            }

            console.log(`Daily notifications completed: ${goodMorningCount} good morning messages sent`);
            return { goodMorningCount };

        } catch (error) {
            console.error('Error in daily notifications:', error);
            throw error;
        }
    });

// Firestore trigger: Monitors product quantity changes and sends low stock alerts immediately
exports.onProductUpdate = functions.firestore
    .document('purchased-products/{userId}/items/{productId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const userId = context.params.userId;

        console.log(`Product updated for user ${userId}: ${newData.productName || 'Unknown'}`);

        try {
            const oldQuantity = oldData.quantity || 0;
            const newQuantity = newData.quantity || 0;

            console.log(`📊 Quantity change: ${oldQuantity} → ${newQuantity}`);

            // Only send notification if quantity actually changed
            if (oldQuantity === newQuantity) {
                console.log('⚪ Quantity unchanged, skipping notification');
                return;
            }

            const minQty = newData.minLimit || 0;
            console.log(`🎯 MinQty threshold: ${minQty}`);

            // Check if this update triggers a low stock alert
            let alertType = null;

            if (newQuantity === 0 && oldQuantity > 0) {
                // Just went out of stock
                alertType = 'order_now';
                console.log('🚨 ORDER NOW alert: Product went out of stock');
            } else if (minQty > 0 && newQuantity <= minQty && newQuantity > 0 && oldQuantity > minQty) {
                // Just reached low stock threshold
                alertType = 'order_soon';
                console.log('⚠️ ORDER SOON alert: Product reached low stock threshold');
            } else {
                console.log('✅ No alert needed for this quantity change');
            }

            if (alertType) {
                console.log(`📤 Sending ${alertType} alert for ${newData.productName || 'Unknown Product'}`);
                await sendLowStockAlert(userId, {
                    name: newData.productName || 'Unknown Product',
                    quantity: newQuantity,
                    unit: newData.unit || 'pcs',
                    imageUrl: newData.imageUrl || null,
                }, alertType);
                console.log(`✅ ${alertType} alert sent successfully`);
            }

        } catch (error) {
            console.error(`❌ Error processing product update for user ${userId}:`, error);
        }
    });

// Send good morning message to all user's devices
async function sendGoodMorningMessage(userId) {
    const tokens = await getUserTokens(userId);

    if (tokens.length === 0) return;

    const message = {
        tokens: tokens,
        notification: {
            title: '🌅 Good Morning!',
            body: 'Have a productive day managing your shop. Check your dashboard for today\'s updates.',
        },
        data: {
            type: 'good_morning',
            timestamp: new Date().toISOString(),
        },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Good morning message sent to ${userId}: ${response.successCount} success, ${response.failureCount} failed`);
}

// Send low stock alert for a single product
async function sendLowStockAlert(userId, product, alertType) {
    try {
        const tokens = await getUserTokens(userId);
        if (tokens.length === 0) return;

        let title, body;

        if (alertType === 'order_soon') {
            title = '🟡 Order Soon Alert';
            body = `${product.name}: ${product.quantity} ${product.unit} remaining (below minimum)`;
        } else if (alertType === 'order_now') {
            title = '🔴 Order Now Alert';
            body = `${product.name} is completely out of stock!`;
        } else {
            return; // Invalid alert type
        }

        const message = {
            tokens: tokens,
            notification: {
                title: title,
                body: body,
                ...(product.imageUrl && { imageUrl: product.imageUrl }),
            },
            android: {
                notification: {
                    icon: 'ic_notification',
                    color: '#FF5722',
                    ...(product.imageUrl && { imageUrl: product.imageUrl }),
                },
            },
            ...(product.imageUrl && {
                apns: {
                    fcm_options: {
                        image: product.imageUrl,
                    },
                },
            }),
            data: {
                type: 'low_stock',
                alertType: alertType,
                productName: product.name,
                quantity: product.quantity.toString(),
                unit: product.unit,
                imageUrl: product.imageUrl || '',
                timestamp: new Date().toISOString(),
            },
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`${alertType} alert sent to ${userId} for ${product.name}: ${response.successCount} success, ${response.failureCount} failed`);

    } catch (error) {
        console.error(`Error sending ${alertType} alert to ${userId}:`, error);
    }
}

// Helper function to get user FCM tokens
async function getUserTokens(userId) {
    try {
        const snapshot = await admin.firestore()
            .collection('users-fcm-tokens')
            .where('userId', '==', userId)
            .get();

        return snapshot.docs.map(doc => doc.data().token).filter(token => token);
    } catch (error) {
        console.error(`Error getting tokens for user ${userId}:`, error);
        return [];
    }
}