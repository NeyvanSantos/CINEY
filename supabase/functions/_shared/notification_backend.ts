import type { Json } from './notification_policy.ts';

export type Env = (key: string) => string | undefined;
export class Backend {
  readonly env: Env;
  readonly fetcher: typeof fetch;
  constructor(env: Env, fetcher: typeof fetch = fetch) { this.env = env; this.fetcher = fetcher; }

  async rest(path: string, method = 'GET', body?: unknown, extra: Record<string, string> = {}): Promise<any> {
    const key = this.env('SUPABASE_SERVICE_ROLE_KEY');
    if (!key || !this.env('SUPABASE_URL')) throw new Error('supabase_not_configured');
    const response = await this.fetcher(`${this.env('SUPABASE_URL')}/rest/v1/${path}`, {
      method, headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', ...extra },
      body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(`database_${response.status}`);
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }

  async state(key: string): Promise<Json | null> {
    const rows = await this.rest(`notification_automation_state?key=eq.${encodeURIComponent(key)}&select=value`);
    return rows[0]?.value ?? null;
  }
  setState(key: string, value: Json) {
    return this.rest('notification_automation_state?on_conflict=key', 'POST', {
      key, value, updated_at: new Date().toISOString(),
    }, { Prefer: 'resolution=merge-duplicates' });
  }
  async devices(userId?: string): Promise<Json[]> {
    const mode = this.env('NOTIFICATIONS_MODE') ?? 'off';
    const recipient = userId ?? (mode === 'test' ? this.env('PUSH_TEST_USER_ID') : undefined);
    if (!userId && mode !== 'live' && (mode !== 'test' || !recipient)) return [];
    const result: Json[] = [];
    for (let offset = 0; offset < 10000; offset += 500) {
      const rows = await this.rest('notification_devices?select=id,user_id,token,notification_preferences(*)' +
        `&order=id&limit=500&offset=${offset}` + (recipient ? `&user_id=eq.${encodeURIComponent(recipient)}` : ''));
      result.push(...rows);
      if (rows.length < 500) return result;
    }
    throw new Error('device_scan_limit'); // Never mark a partial fanout complete.
  }
  async enqueue(jobs: Json[]) {
    for (let i = 0; i < jobs.length; i += 100) {
      await this.rest('notification_jobs?on_conflict=device_id,dedupe_key', 'POST', jobs.slice(i, i + 100),
        { Prefer: 'resolution=ignore-duplicates' });
    }
  }
}

const encoder = new TextEncoder();
const base64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes))
  .replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');

export async function secretMatches(provided: string, expected: string | undefined): Promise<boolean> {
  if (!expected || expected.length < 32 || provided.length > 256) return false;
  const [a, b] = await Promise.all([provided, expected].map(async (text) =>
    new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(text)))));
  return a.reduce((diff, byte, i) => diff | (byte ^ b[i]), 0) === 0;
}

export class FirebaseSender {
  private cached?: { token: string; expires: number };
  private authenticating?: Promise<string>;
  readonly env: Env;
  readonly fetcher: typeof fetch;
  constructor(env: Env, fetcher: typeof fetch = fetch) { this.env = env; this.fetcher = fetcher; }

  config(): Json {
    let account: Json;
    try { account = JSON.parse(this.env('FIREBASE_SERVICE_ACCOUNT') ?? '{}'); }
    catch { throw new Error('firebase_config_invalid'); }
    if (account.type !== 'service_account' || account.project_id !== 'ciney-594e2' ||
        typeof account.client_email !== 'string' || typeof account.private_key !== 'string') {
      throw new Error('firebase_config_invalid');
    }
    return account;
  }
  async accessToken(): Promise<string> {
    if (this.cached && this.cached.expires > Date.now() + 60000) return this.cached.token;
    if (!this.authenticating) {
      this.authenticating = this.authenticate().finally(() => { this.authenticating = undefined; });
    }
    return this.authenticating;
  }
  private async authenticate(): Promise<string> {
    const account = this.config();
    const iat = Math.floor(Date.now() / 1000);
    const header = base64url(encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
    const claims = base64url(encoder.encode(JSON.stringify({ iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token', iat, exp: iat + 3600 })));
    const der = Uint8Array.from(atob(account.private_key.replace(/-----[^-]+-----|\s/g, '')), (c) => c.charCodeAt(0));
    const key = await crypto.subtle.importKey('pkcs8', der,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
    const assertion = `${header}.${claims}.` + base64url(new Uint8Array(await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5', key, encoder.encode(`${header}.${claims}`))));
    const response = await this.fetcher('https://oauth2.googleapis.com/token', {
      method: 'POST', body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error('firebase_auth_failed');
    const result = await response.json();
    if (typeof result.access_token !== 'string') throw new Error('firebase_auth_failed');
    this.cached = { token: result.access_token, expires: Date.now() + Number(result.expires_in ?? 3600) * 1000 };
    return result.access_token;
  }
  async send(token: string | null, title: string, body: string, data: Json, tag: string, validateOnly = false) {
    const project = this.config().project_id;
    const response = await this.fetcher(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
      method: 'POST', headers: { Authorization: `Bearer ${await this.accessToken()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ validate_only: validateOnly, message: {
        ...(token ? { fid: token } : { topic: 'ciney-configuration-check' }),
        notification: { title, body }, data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
        android: { priority: 'normal', ttl: '86400s', notification: {
          channel_id: 'ciney_announcements', icon: 'ic_notification', color: '#FF6B00', tag,
        } },
      } }), signal: AbortSignal.timeout(15000),
    });
    const result = await response.json().catch(() => ({}));
    const unregistered = result.error?.details?.some((detail: Json) =>
      detail['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError' && detail.errorCode === 'UNREGISTERED') === true;
    return { ok: response.ok, status: response.status, unregistered };
  }
}
