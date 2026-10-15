import { test } from 'node:test';
import assert from 'node:assert/strict';
import { brasilDate, catalogItem, digestFor, episodeIdentity, latestMobileRelease,
  newerVersion, preferencesAllow, transientFcmError } from '../functions/_shared/notification_policy.ts';
import { Backend, FirebaseSender, secretMatches } from '../functions/_shared/notification_backend.ts';
import { createHandler as workerHandler, NotificationWorker } from '../functions/notification-worker/index.ts';
import { createHandler as selfTestHandler } from '../functions/notification-self-test/index.ts';

const preferences = { enabled: true, movies: true, series: true, anime: true,
  dorama: true, episodes: true, app_updates: true };
const env = (values: Record<string, string> = {}) => (key: string) => values[key];
const neverFetch = async () => { throw new Error('Unexpected network access'); };

test('Brasilia digest dates do not change at midnight UTC', () => {
  assert.equal(brasilDate(new Date('2026-10-16T01:00:00Z')), '2026-10-15');
});
test('only valid, recent, already announced titles enter the catalog', () => {
  const now = new Date('2026-10-15T12:00:00Z');
  assert.equal(catalogItem({ id: 42, title: 'Filme', release_date: '2026-10-14' }, 'movie', now)?.key, 'movie:42');
  for (const date of ['2026-10-16', '2020-01-01', 'invalid', '']) {
    assert.equal(catalogItem({ id: 42, name: 'A', first_air_date: date }, 'anime', now), null);
  }
  assert.equal(catalogItem({ id: -1, title: 'A', release_date: '2026-10-14' }, 'movie', now), null);
});
test('preferences filter digests, favorite episodes and application updates independently', () => {
  const prefs = { ...preferences, movies: false, app_updates: false };
  const digest = digestFor([{ category: 'movie' }, { category: 'anime' }], prefs)!;
  assert.equal(digest.categories, 'anime');
  assert.equal(digest.body.includes('filmes'), false);
  assert.equal(preferencesAllow(prefs, 'digest', { categories: 'movie,anime' }), false);
  assert.equal(preferencesAllow(prefs, 'digest', { categories: 'anime' }), true);
  assert.equal(preferencesAllow(prefs, 'digest', {}), false);
  assert.equal(preferencesAllow(prefs, 'app_update', {}), false);
  assert.equal(preferencesAllow({ ...prefs, episodes: false }, 'episode', { category: 'anime' }), false);
  assert.equal(digestFor([{ category: 'anime' }], { ...prefs, enabled: false }), null);
});
test('official mobile release must contain the matching uploaded APK', () => {
  const release = (tag: string, extra = {}) => ({ tag_name: tag,
    assets: [{ name: `CiNey-${tag}.apk`, state: 'uploaded', size: 100 }], ...extra });
  const latest = latestMobileRelease([release('tv-v9.0.0'), release('v2.0.0', { prerelease: true }),
    release('v3.0.0', { draft: true }), release('v4.0.0', { assets: [] }), release('v1.0.9'), release('v1.0.40')]);
  assert.equal(latest?.tag_name, 'v1.0.40');
  assert.equal(newerVersion('v1.0.40', 'v1.0.9'), true);
  assert.equal(newerVersion('v1.0.9', 'v1.0.40'), false);
  assert.equal(newerVersion('v1.0.40', 'v1.0.40'), false);
});
test('episode announcements reject future, invalid and special episodes', () => {
  const episode = (air_date: string, season_number = 1) => ({ last_episode_to_air: { air_date, season_number, episode_number: 2 } });
  assert.equal(episodeIdentity(episode('2020-01-01')), '1:2');
  for (const date of ['2099-01-01', 'invalid', '2020-no-no']) assert.equal(episodeIdentity(episode(date)), null);
  assert.equal(episodeIdentity(episode('2020-01-01', 0)), null);
});
test('job secret and recipient mode default to deny', async () => {
  assert.equal(await secretMatches('x', undefined), false);
  assert.equal(await secretMatches('x', 'short'), false);
  assert.equal(await secretMatches('b'.repeat(40), 'a'.repeat(40)), false);
  assert.equal(await secretMatches('a'.repeat(40), 'a'.repeat(40)), true);
  assert.deepEqual(await new Backend(env(), neverFetch).devices(), []);
  assert.deepEqual(await new Backend(env({ NOTIFICATIONS_MODE: 'test' }), neverFetch).devices(), []);
  assert.deepEqual(await new NotificationWorker(env(), neverFetch).dispatch(), { sent: 0, mode: 'off' });
});
test('worker rejects unauthenticated requests before touching credentials/database', async () => {
  const handler = workerHandler(env({ NOTIFICATIONS_JOB_SECRET: 'a'.repeat(40) }), neverFetch);
  assert.equal((await handler(new Request('https://example.com', { method: 'POST', body: '{}' }))).status, 401);
  assert.equal((await handler(new Request('https://example.com'))).status, 405);
});
test('first catalog scan seeds silently and off mode never queues later scans', async () => {
  for (const mode of [undefined, 'off', 'test']) {
    const worker = new NotificationWorker(env(mode ? { NOTIFICATIONS_MODE: mode } : {}));
    let previous: any = null;
    const inserted: any[] = [];
    worker.db.state = async () => previous;
    worker.db.setState = async () => null;
    worker.db.rest = async (_path, _method, body: any) => { inserted.push(...body); return null; };
    worker.tmdb = async () => ({ results: [{ id: 1, title: 'A', release_date: new Date().toISOString().slice(0, 10) }] });
    await worker.scanCatalog();
    assert.equal(inserted.every((row) => row.pending === false), true);
    previous = {};
    inserted.length = 0;
    await worker.scanCatalog();
    assert.equal(inserted.every((row) => row.pending === (mode === 'test')), true);
  }
});
test('health uses FCM validate_only and never performs delivery', async () => {
  const key = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const der = await crypto.subtle.exportKey('pkcs8', key.privateKey);
  const account = { type: 'service_account', project_id: 'ciney-594e2', client_email: 'test@example.com',
    private_key: '-----BEGIN PRIVATE KEY-----\n' + Buffer.from(der).toString('base64') + '\n-----END PRIVATE KEY-----' };
  const calls: any[] = [];
  const fetcher = async (input: any, init: any) => {
    if (String(input).includes('oauth2.googleapis.com')) return Response.json({ access_token: 'unit-test-token', expires_in: 3600 });
    assert.equal(String(input), 'https://fcm.googleapis.com/v1/projects/ciney-594e2/messages:send');
    calls.push(JSON.parse(init.body));
    return Response.json({ name: 'validation-only' });
  };
  const handler = workerHandler(env({ FIREBASE_SERVICE_ACCOUNT: JSON.stringify(account),
    NOTIFICATIONS_JOB_SECRET: 'a'.repeat(40) }), fetcher as typeof fetch);
  const response = await handler(new Request('https://example.com', { method: 'POST',
    headers: { 'x-ciney-job-key': 'a'.repeat(40) }, body: JSON.stringify({ action: 'health' }) }));
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].validate_only, true);
  assert.equal(calls[0].message.topic, 'ciney-configuration-check');
  assert.equal(calls[0].message.token, undefined);
});
test('self-test verifies identity and never accepts another account/device', async () => {
  const noAuth = await selfTestHandler(env(), neverFetch)(new Request('https://example.com', { method: 'POST', body: '{}' }));
  assert.equal(noAuth.status, 401);
  const paths: string[] = [];
  const fetcher = async (input: any) => {
    const path = String(input); paths.push(path);
    if (path.endsWith('/auth/v1/user')) return Response.json({ id: 'owner', email_confirmed_at: '2026-01-01' });
    if (path.includes('/notification_devices?')) {
      assert.equal(path.includes('user_id=eq.owner'), true);
      return Response.json([{ token: 'owned-token'.repeat(4), notification_preferences: preferences }]);
    }
    throw new Error('Must never reach FCM or rate limit for foreign device');
  };
  const handler = selfTestHandler(env({ SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'server-test-only' }), fetcher as typeof fetch);
  const response = await handler(new Request('https://example.com', { method: 'POST',
    headers: { Authorization: 'Bearer user-test-jwt' }, body: JSON.stringify({ token: 'foreign-token'.repeat(4), user_id: 'victim' }) }));
  assert.equal(response.status, 404);
  assert.equal(paths.length, 2);
});
test('only explicit FCM UNREGISTERED deletes a token; transport failures retry', async () => {
  assert.equal(transientFcmError(429), true);
  assert.equal(transientFcmError(500), true);
  assert.equal(transientFcmError(400), false);
  for (const explicit of [false, true]) {
    const sender = new FirebaseSender(env(), (async () => Response.json({ error: { details: explicit
      ? [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'UNREGISTERED' }] : [] } }, { status: 404 })) as typeof fetch);
    sender.config = () => ({ project_id: 'ciney-594e2' });
    sender.accessToken = async () => 'test';
    assert.equal((await sender.send('token', 'A', 'B', {}, 'test')).unregistered, explicit);
  }
});

test('dispatch rechecks preferences, retries transient failures and cancels other test accounts', async () => {
  for (const scenario of ['sent', 'retry', 'disabled', 'other-user', 'unregistered']) {
    const worker = new NotificationWorker(env({ NOTIFICATIONS_MODE: 'test', PUSH_TEST_USER_ID: 'owner' }));
    const writes: any[] = [];
    let sends = 0;
    worker.db.rest = async (path, method, body) => {
      if (path === 'rpc/claim_notification_jobs') return [{ id: 'job', claim_token: 'lease', device_id: 'device',
        attempts: 1, kind: 'app_update', title: 'A', body: 'B', dedupe_key: 'release:v1.0.41', data: {} }];
      if (path.startsWith('notification_devices?') && !method) return [{ token: 'fid',
        user_id: scenario === 'other-user' ? 'victim' : 'owner',
        notification_preferences: { ...preferences, enabled: scenario !== 'disabled' } }];
      writes.push({ path, method, body });
      return null;
    };
    worker.firebase.send = async () => {
      sends++;
      return { ok: scenario === 'sent', status: scenario === 'retry' ? 503 : 200, unregistered: scenario === 'unregistered' };
    };
    const result = await worker.dispatch();
    if (scenario === 'unregistered') assert.equal(writes[0].method, 'DELETE');
    else assert.equal(writes[0].body.status, ({ sent: 'sent', retry: 'retry', disabled: 'cancelled', 'other-user': 'cancelled' } as any)[scenario]);
    assert.equal(sends, ['disabled', 'other-user'].includes(scenario) ? 0 : 1);
    assert.equal(result.sent, scenario === 'sent' ? 1 : 0);
    if (writes[0].method === 'PATCH') assert.equal(writes[0].path.includes('claim_token=eq.lease'), true);
  }
});
test('self-test enforces account-level rate limiting before FCM delivery', async () => {
  const fetcher = async (input: any) => {
    const path = String(input);
    if (path.endsWith('/auth/v1/user')) return Response.json({ id: 'owner', email_confirmed_at: '2026-01-01' });
    if (path.includes('/notification_devices?')) return Response.json([{ token: 'owned-token'.repeat(4), notification_preferences: preferences }]);
    if (path.endsWith('/rpc/notification_allow_self_test')) return Response.json(false);
    throw new Error('Must never send when rate limited');
  };
  const handler = selfTestHandler(env({ SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-only' }), fetcher as typeof fetch);
  const response = await handler(new Request('https://example.com', { method: 'POST',
    headers: { Authorization: 'Bearer test-jwt' }, body: JSON.stringify({ token: 'owned-token'.repeat(4) }) }));
  assert.equal(response.status, 429);
});
