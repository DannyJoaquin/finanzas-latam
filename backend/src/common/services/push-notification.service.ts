import { Injectable, Logger } from '@nestjs/common';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';

/** Maximum push notifications sent to the same user per calendar day */
const MAX_DAILY_PUSH = 3;

/** How long a daily counter key lives in Redis (slightly over 24h to cover midnight edge cases) */
const REDIS_TTL_SECONDS = 25 * 60 * 60;

export interface PushPayload {
  userId: string;
  fcmToken: string;
  title: string;
  body: string;
  /** Optional string-only data map forwarded to the device */
  data?: Record<string, string>;
}

@Injectable()
export class PushNotificationService {
  private readonly logger = new Logger(PushNotificationService.name);

  /**
   * Cached firebase-admin messaging instance.
   * null  → Firebase not configured / not installed.
   * false → Already tried and failed; do not retry.
   */
  private messaging: any = null;
  private firebaseReady = false;

  constructor(@InjectRedis() private readonly redis: Redis) {
    this.initFirebase();
  }

  // ─────────────────────────── Firebase init ───────────────────────────────

  private initFirebase(): void {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!serviceAccountJson) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT env var not set — push notifications are disabled. ' +
          'Add it with your Firebase Admin SDK credentials JSON to enable FCM.',
      );
      return;
    }

    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const admin = require('firebase-admin');
      if (!admin.apps.length) {
        admin.initializeApp({
          credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
        });
      }
      this.messaging = admin.messaging();
      this.firebaseReady = true;
      this.logger.log('Firebase Admin SDK initialized — push notifications enabled');
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.warn(
        `Firebase Admin could not be initialized (${msg}). ` +
          'Run "npm install firebase-admin" inside the container if the package is missing.',
      );
    }
  }

  // ─────────────────────────── Public API ──────────────────────────────────

  /**
   * Attempt to send a push notification.
   *
   * Enforces a hard cap of MAX_DAILY_PUSH per user per calendar day.
   * Returns `true` if the message was dispatched, `false` otherwise.
   */
  async send(payload: PushPayload): Promise<boolean> {
    const { userId, fcmToken, title, body, data } = payload;

    // ── Daily rate-limit check ───────────────────────────────────────────
    const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const key = `push:daily:${userId}:${today}`;

    const count = await this.redis.incr(key);
    if (count === 1) {
      // First increment today — set TTL so the key auto-expires
      await this.redis.expire(key, REDIS_TTL_SECONDS);
    }

    if (count > MAX_DAILY_PUSH) {
      this.logger.debug(
        `Daily push cap (${MAX_DAILY_PUSH}) reached for user ${userId} — skipping: "${title}"`,
      );
      // Decrement so we don't inflate the counter for messages that weren't sent
      await this.redis.decr(key);
      return false;
    }

    // ── Send via FCM ─────────────────────────────────────────────────────
    if (!this.firebaseReady) {
      this.logger.debug(`[PUSH STUB] Would send to ${userId}: "${title}" — "${body}"`);
      // Still counts against the daily quota so we don't spam logs when live
      return false;
    }

    try {
      await this.messaging.send({
        token: fcmToken,
        notification: { title, body },
        data: data ?? {},
        android: { priority: 'high' as const },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      });
      this.logger.log(`Push sent [${count}/${MAX_DAILY_PUSH} today] to user ${userId}: "${title}"`);
      return true;
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`FCM send failed for user ${userId}: ${msg}`);
      // Refund the quota slot — message was never delivered
      await this.redis.decr(key);
      return false;
    }
  }

  /** How many push notifications can still be sent to this user today */
  async remainingToday(userId: string): Promise<number> {
    const today = new Date().toISOString().slice(0, 10);
    const key = `push:daily:${userId}:${today}`;
    const count = parseInt((await this.redis.get(key)) ?? '0', 10);
    return Math.max(0, MAX_DAILY_PUSH - count);
  }
}
