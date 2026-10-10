import { createClient } from 'npm:@supabase/supabase-js@2';

const maxPayloadBytes = 220 * 1024;
const maxLogs = 500;
const maxReportsPerHour = 5;
const allowedLevels = new Set(['DEBUG', 'INFO', 'WARN', 'ERROR', 'OK']);
const allowedPlatforms = new Set([
  'android',
  'ios',
  'windows',
  'macos',
  'linux',
  'fuchsia',
  'other',
]);

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

const sanitizeText = (value: string) => value
  .replace(/\bBearer\s+[^\s,;]+/gi, 'Bearer [REDACTED]')
  .replace(
    /\b(password|passwd|access[_-]?token|refresh[_-]?token|authorization|api[_-]?key|secret)(\s*[:=]\s*)("[^"]*"|'[^']*'|[^\s,;]+)/gi,
    '$1$2[REDACTED]',
  )
  .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[EMAIL]')
  .replace(/https?:\/\/[^\s?]+\?[^\s]+/gi, (url) => `${url.split('?')[0]}?[REDACTED]`);

const normalizeLogs = (value: unknown) => {
  if (!Array.isArray(value) || value.length < 1 || value.length > maxLogs) return null;
  const result = [];
  for (const item of value) {
    if (typeof item !== 'object' || item === null || Array.isArray(item)) return null;
    const log = item as Record<string, unknown>;
    const timestamp = typeof log.timestamp === 'string' ? log.timestamp : '';
    const level = typeof log.level === 'string' ? log.level.toUpperCase() : '';
    const tag = typeof log.tag === 'string' ? log.tag : '';
    const message = typeof log.message === 'string' ? log.message : '';
    if (!Number.isFinite(Date.parse(timestamp)) || !allowedLevels.has(level)) return null;
    if (tag.length > 200 || message.length > 4000) return null;
    result.push({
      timestamp: new Date(timestamp).toISOString(),
      level,
      tag: sanitizeText(tag),
      message: sanitizeText(message),
    });
  }
  return result;
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json(405, { error: 'Method not allowed' });

  const authorization = request.headers.get('Authorization');
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return json(401, { error: 'Authentication required' });

  const contentLength = Number(request.headers.get('content-length') ?? 0);
  if (contentLength > maxPayloadBytes) return json(413, { error: 'Report is too large' });
  const rawBody = await request.arrayBuffer();
  if (rawBody.byteLength > maxPayloadBytes) return json(413, { error: 'Report is too large' });

  let body: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(new TextDecoder().decode(rawBody));
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      return json(400, { error: 'Invalid report' });
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json(400, { error: 'Invalid report' });
  }

  const logs = normalizeLogs(body.logs);
  const description = typeof body.description === 'string' ? sanitizeText(body.description).trim() : '';
  const appVersion = typeof body.app_version === 'string' ? body.app_version.trim() : '';
  const platform = typeof body.platform === 'string' ? body.platform.toLowerCase() : '';
  if (!logs || description.length > 1000 || appVersion.length < 1 || appVersion.length > 100 || !allowedPlatforms.has(platform)) {
    return json(400, { error: 'Invalid report' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(500, { error: 'Report service is not configured' });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser(token);
  if (userError || !user) return json(401, { error: 'Invalid session' });

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const retentionCutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    await admin.from('diagnostic_reports').delete().lt('created_at', retentionCutoff);

    const rateLimitCutoff = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { count, error: countError } = await admin
      .from('diagnostic_reports')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('created_at', rateLimitCutoff);
    if (countError) return json(500, { error: 'Could not validate report limit' });
    if ((count ?? 0) >= maxReportsPerHour) {
      return json(429, { error: 'Report limit reached. Try again later.' });
    }

    const { data, error } = await admin
      .from('diagnostic_reports')
      .insert({
        user_id: user.id,
        description,
        app_version: appVersion,
        platform,
        logs,
      })
      .select('id')
      .single();
    if (error || !data) return json(500, { error: 'Could not save report' });
    return json(201, { report_id: data.id });
  } catch {
    return json(500, { error: 'Could not save report' });
  }
});