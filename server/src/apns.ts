// APNs silent push helper
import apn from 'apn';

let apnProvider: apn.Provider | null = null;

export function initializeAPNs() {
  const keyPath = process.env.APNS_KEY_PATH;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const production = process.env.APNS_PRODUCTION === 'true';

  if (!keyPath || !keyId || !teamId) {
    console.warn('⚠️  APNs not configured. Set APNS_KEY_PATH, APNS_KEY_ID, APNS_TEAM_ID in .env');
    console.warn('   Push notifications will be skipped. Use polling mode in iOS app.');
    return null;
  }

  apnProvider = new apn.Provider({
    token: {
      key: keyPath,
      keyId: keyId,
      teamId: teamId,
    },
    production: production,
  });

  console.log(`✅ APNs initialized (${production ? 'production' : 'sandbox'})`);
  return apnProvider;
}

export async function sendSilentPush(
  deviceToken: string,
  payload: { envelope: string },
): Promise<boolean> {
  if (!apnProvider) {
    console.log('⚠️  APNs not available, skipping push');
    return false;
  }

  const notification = new apn.Notification();
  notification.topic = process.env.APNS_BUNDLE_ID || 'com.example.GPTReminders';
  notification.contentAvailable = true; // Silent push
  notification.priority = 5; // Immediate delivery
  notification.payload = payload;

  try {
    const result = await apnProvider.send(notification, deviceToken);

    if (result.failed.length > 0) {
      console.error('❌ APNs send failed:', result.failed[0].response);
      return false;
    }

    console.log('✅ Silent push sent to device');
    return true;
  } catch (error) {
    console.error('❌ APNs error:', error);
    return false;
  }
}

export function shutdownAPNs() {
  if (apnProvider) {
    apnProvider.shutdown();
    apnProvider = null;
  }
}
