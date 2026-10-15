import { Backend, FirebaseSender, type Env } from '../_shared/notification_backend.ts';

export function createHandler(env: Env, fetcher: typeof fetch = fetch) {
  const db = new Backend(env, fetcher);
  const firebase = new FirebaseSender(env, fetcher);
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return Response.json({ error: 'method_not_allowed' }, { status: 405 });
    const authorization = request.headers.get('Authorization') ?? '';
    if (!authorization.startsWith('Bearer ')) return Response.json({ error: 'sign_in_first' }, { status: 401 });
    try {
      const response = await fetcher(`${env('SUPABASE_URL')}/auth/v1/user`, {
        headers: { Authorization: authorization, apikey: env('SUPABASE_ANON_KEY') ?? '' }, signal: AbortSignal.timeout(10000),
      });
      if (!response.ok) return Response.json({ error: 'sign_in_first' }, { status: 401 });
      const user = await response.json();
      if (!user.id || !user.email_confirmed_at) return Response.json({ error: 'confirmed_account_required' }, { status: 401 });
      const input = await request.json();
      const token = typeof input.token === 'string' ? input.token : '';
      if (token.length < 20 || token.length > 4096) return Response.json({ error: 'invalid_device' }, { status: 400 });
      const devices = await db.devices(user.id);
      const device = devices.find((d) => d.token === token);
      if (!device || !device.notification_preferences?.enabled) return Response.json({ error: 'device_not_registered' }, { status: 404 });
      if (!await db.rest('rpc/notification_allow_self_test', 'POST', { caller_id: user.id })) {
        return Response.json({ error: 'try_again_in_one_minute' }, { status: 429 });
      }
      const result = await firebase.send(token, 'Notificações do CiNey ativadas',
        'Este é um aviso de teste enviado somente para este aparelho.', { kind: 'test' }, 'ciney-self-test');
      return Response.json({ sent: result.ok }, { status: result.ok ? 200 : 502 });
    } catch {
      return Response.json({ error: 'test_unavailable' }, { status: 503 });
    }
  };
}
if (typeof Deno !== 'undefined') Deno.serve(createHandler((name) => Deno.env.get(name)));
