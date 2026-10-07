import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const digest = async (value: string) => {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, '0')).join('');
};

const randomSecret = () => {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json(405, { error: 'Method not allowed' });

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(500, { error: 'Pairing service is not configured' });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const body = await request.json();
    const action = body?.action;

    if (action === 'start') {
      await admin.from('tv_pairing_requests').delete().lt('expires_at', new Date().toISOString());
      const id = crypto.randomUUID();
      const secret = randomSecret();
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
      const { error } = await admin.from('tv_pairing_requests').insert({
        id,
        secret_hash: await digest(secret),
        expires_at: expiresAt,
      });
      if (error) return json(500, { error: 'Could not create pairing request' });
      return json(200, { id, secret, expiresAt });
    }

    const id = typeof body?.id === 'string' ? body.id : '';
    const secret = typeof body?.secret === 'string' ? body.secret : '';
    if (!/^[0-9a-f-]{36}$/i.test(id) || secret.length < 32 || secret.length > 64) {
      return json(400, { error: 'Invalid pairing request' });
    }
    const secretHash = await digest(secret);

    if (action === 'approve') {
      const authorization = request.headers.get('Authorization');
      if (!authorization?.startsWith('Bearer ')) return json(401, { error: 'Sign in first' });
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authorization } },
        auth: { autoRefreshToken: false, persistSession: false },
      });
      const { data: { user }, error: userError } = await userClient.auth.getUser();
      if (userError || !user?.email || !user.email_confirmed_at) {
        return json(401, { error: 'A confirmed account is required' });
      }

      const { data, error } = await admin
        .from('tv_pairing_requests')
        .update({ status: 'approved', user_id: user.id })
        .eq('id', id)
        .eq('secret_hash', secretHash)
        .eq('status', 'pending')
        .gt('expires_at', new Date().toISOString())
        .select('id')
        .maybeSingle();
      if (error) return json(500, { error: 'Could not approve pairing' });
      if (!data) return json(404, { error: 'Pairing request expired or already used' });
      return json(200, { status: 'approved' });
    }

    const { data: pairing, error: pairingError } = await admin
      .from('tv_pairing_requests')
      .select('status, user_id, auth_email, auth_token_hash, expires_at')
      .eq('id', id)
      .eq('secret_hash', secretHash)
      .maybeSingle();
    if (pairingError) return json(500, { error: 'Could not read pairing request' });
    if (!pairing || new Date(pairing.expires_at).getTime() <= Date.now()) {
      return json(404, { error: 'Pairing request expired' });
    }

    if (action === 'poll') {
      if (pairing.status === 'pending') return json(200, { status: 'pending' });
      if (pairing.status !== 'approved' || !pairing.user_id) {
        return json(409, { error: 'Pairing request already used' });
      }

      let email = pairing.auth_email;
      let tokenHash = pairing.auth_token_hash;
      if (!email || !tokenHash) {
        const { data: { user }, error: userError } = await admin.auth.admin.getUserById(pairing.user_id);
        if (userError || !user?.email) return json(404, { error: 'Account is unavailable' });
        const { data, error } = await admin.auth.admin.generateLink({
          type: 'magiclink',
          email: user.email,
        });
        const generatedToken = data?.properties?.hashed_token;
        if (error || !generatedToken) return json(500, { error: 'Could not issue TV session' });

        await admin
          .from('tv_pairing_requests')
          .update({ auth_email: user.email, auth_token_hash: generatedToken })
          .eq('id', id)
          .eq('status', 'approved')
          .is('auth_token_hash', null);
        const { data: saved } = await admin
          .from('tv_pairing_requests')
          .select('auth_email, auth_token_hash')
          .eq('id', id)
          .single();
        email = saved?.auth_email ?? null;
        tokenHash = saved?.auth_token_hash ?? null;
      }
      if (!email || !tokenHash) return json(500, { error: 'Could not issue TV session' });
      return json(200, { status: 'ready', email, tokenHash });
    }

    if (action === 'complete') {
      const { error } = await admin
        .from('tv_pairing_requests')
        .update({ status: 'consumed', auth_token_hash: null })
        .eq('id', id)
        .eq('secret_hash', secretHash)
        .eq('status', 'approved');
      if (error) return json(500, { error: 'Could not finish pairing' });
      return json(200, { status: 'consumed' });
    }

    return json(400, { error: 'Unknown action' });
  } catch {
    return json(400, { error: 'Invalid pairing request' });
  }
});