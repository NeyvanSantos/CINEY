import { Backend, FirebaseSender, secretMatches, type Env } from '../_shared/notification_backend.ts';
import { brasilDate, catalogItem, categories, digestFor, episodeIdentity,
  latestMobileRelease, newerVersion, preferencesAllow, transientFcmError, type Json } from '../_shared/notification_policy.ts';

const reply = (status: number, value: Json) => Response.json(value, { status });
const pluginIds: Json = { movie: 'com.megaflix', series: 'com.supercine', anime: 'com.animescloud', dorama: 'com.doramas' };

export class NotificationWorker {
  readonly db: Backend;
  readonly firebase: FirebaseSender;
  readonly env: Env;
  readonly fetcher: typeof fetch;
  constructor(env: Env, fetcher: typeof fetch = fetch) {
    this.env = env;
    this.fetcher = fetcher;
    this.db = new Backend(env, fetcher);
    this.firebase = new FirebaseSender(env, fetcher);
  }
  async tmdb(path: string): Promise<Json> {
    const apiKey = this.env('TMDB_API_KEY');
    if (!apiKey) throw new Error('tmdb_not_configured');
    const url = new URL(`https://api.themoviedb.org/3/${path}`);
    url.searchParams.set('api_key', apiKey);
    url.searchParams.set('language', 'pt-BR');
    const response = await this.fetcher(url, { signal: AbortSignal.timeout(8000) });
    if (!response.ok) throw new Error(`tmdb_${response.status}`);
    return response.json();
  }
  async scanCatalog() {
    const paths = ['trending/movie/week', 'trending/tv/week',
      'discover/tv?with_genres=16&with_original_language=ja&sort_by=popularity.desc',
      'discover/tv?with_original_language=ko&sort_by=popularity.desc'];
    let count = 0;
    for (let i = 0; i < categories.length; i++) {
      const category = categories[i];
      const previous = await this.db.state(`catalog:${category}`);
      const result = await this.tmdb(paths[i]);
      if (!Array.isArray(result.results)) throw new Error('catalog_response_invalid');
      const items = result.results.map((row: Json) => catalogItem(row, category)).filter((item: Json | null): item is Json => item !== null);
      if (items.length) {
        await this.db.rest('notification_catalog?on_conflict=key', 'POST', items.map((item: Json) => ({
          ...item, pending: previous !== null && ['test', 'live'].includes(this.env('NOTIFICATIONS_MODE') ?? 'off'),
        })), { Prefer: 'resolution=ignore-duplicates' });
      }
      await this.db.setState(`catalog:${category}`, { scanned_at: new Date().toISOString() });
      count += items.length;
    }
    return count;
  }
  async scanRelease() {
    const response = await this.fetcher('https://api.github.com/repos/NeyvanSantos/CINEY/releases?per_page=50', {
      headers: { 'User-Agent': 'CiNey-Notifications', Accept: 'application/vnd.github+json' },
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw new Error(`releases_${response.status}`);
    const latest = latestMobileRelease(await response.json());
    if (!latest) return;
    const previous = await this.db.state('release:mobile');
    if (previous && newerVersion(latest.tag_name, previous.tag)) {
      const devices = await this.db.devices();
      const data = { kind: 'app_update', version: latest.tag_name.slice(1) };
      await this.db.enqueue(devices.filter((d) => preferencesAllow(d.notification_preferences, 'app_update', data))
        .map((d) => ({ device_id: d.id, dedupe_key: `release:${latest.tag_name}`, kind: 'app_update',
          title: `CiNey ${data.version} disponível`,
          body: 'Uma nova versão oficial foi publicada. Abra para conferir as novidades e atualizar.', data })));
    }
    if (!previous || newerVersion(latest.tag_name, previous.tag)) {
      await this.db.setState('release:mobile', { tag: latest.tag_name, scanned_at: new Date().toISOString() });
    }
  }
  async scanEpisodes() {
    const devices = await this.db.devices();
    if (!devices.length) return 0;
    const users = [...new Set(devices.map((d) => d.user_id))];
    const favorites: Json[] = [];
    for (let offset = 0; offset < users.length; offset += 50) {
      const batch = users.slice(offset, offset + 50);
      for (let page = 0; page < 10000; page += 500) {
        const rows = await this.db.rest(`favorites?select=user_id,content_id,content_type,title&user_id=in.(${batch.join(',')})` +
          `&content_type=in.(series,anime,dorama)&order=id&limit=500&offset=${page}`);
        favorites.push(...rows);
        if (rows.length < 500) break;
        if (page === 9500) throw new Error('favorite_scan_limit');
      }
    }
    const ids = [...new Set(favorites.map((f) => /^tmdb_(\d+)_(series|anime|dorama)$/.exec(f.content_id)?.[1]).filter(Boolean))].sort();
    const cursor = (await this.db.state('episodes:cursor'))?.offset ?? 0;
    const selected = ids.slice(Number(cursor), Number(cursor) + 20);
    for (let start = 0; start < selected.length; start += 4) {
      await Promise.all(selected.slice(start, start + 4).map(async (id) => {
        const detail = await this.tmdb(`tv/${id}`);
        const identity = episodeIdentity(detail);
        if (!identity) return;
        const previous = await this.db.state(`episode:${id}`);
        if (previous && previous.identity !== identity) {
          const [season, episode] = identity.split(':');
          const followers = favorites.filter((f) => f.content_id.startsWith(`tmdb_${id}_`));
          const jobs = devices.flatMap((device) => {
            const favorite = followers.find((f) => f.user_id === device.user_id);
            if (!favorite) return [];
            const data = { kind: 'episode', category: favorite.content_type, tmdb_id: String(id),
              season, episode, title: String(detail.name ?? favorite.title).slice(0, 120) };
            if (!preferencesAllow(device.notification_preferences, 'episode', data)) return [];
            return [{ device_id: device.id, dedupe_key: `episode:${id}:${identity}`, kind: 'episode',
              title: 'Novo episódio anunciado',
              body: `${data.title} — temporada ${season}, episódio ${episode}. Confira os detalhes no CiNey.`.slice(0, 1000), data }];
          });
          await this.db.enqueue(jobs);
        }
        await this.db.setState(`episode:${id}`, { identity });
      }));
    }
    await this.db.setState('episodes:cursor', { offset: Number(cursor) + 20 >= ids.length ? 0 : Number(cursor) + 20 });
    return selected.length;
  }
  async digest() {
    const devices = await this.db.devices();
    if (!devices.length) return 0;
    const cutoff = new Date().toISOString();
    const items: Json[] = [];
    for (let offset = 0; offset < 10000; offset += 500) {
      const page = await this.db.rest(`notification_catalog?pending=eq.true&first_seen_at=lte.${encodeURIComponent(cutoff)}&select=category&order=key&limit=500&offset=${offset}`);
      items.push(...page);
      if (page.length < 500) break;
      if (offset === 9500) throw new Error('catalog_scan_limit');
    }
    if (!items.length) return 0;
    const jobs = devices.flatMap((d) => {
      const summary = digestFor(items, d.notification_preferences);
      if (!summary) return [];
      return [{ device_id: d.id, dedupe_key: `digest:${brasilDate()}`, kind: 'digest',
        title: 'Novidades no catálogo do CiNey', body: summary.body,
        data: { kind: 'digest', categories: summary.categories } }];
    });
    await this.db.enqueue(jobs);
    await this.db.rest(`notification_catalog?pending=eq.true&first_seen_at=lte.${encodeURIComponent(cutoff)}`, 'PATCH', { pending: false });
    return jobs.length;
  }
  async dispatch() {
    const mode = this.env('NOTIFICATIONS_MODE') ?? 'off';
    if (mode === 'off' || !['test', 'live'].includes(mode)) return { sent: 0, mode };
    if (mode === 'test' && !this.env('PUSH_TEST_USER_ID')) return { sent: 0, mode };
    const jobs = await this.db.rest('rpc/claim_notification_jobs', 'POST', { batch_size: 20 });
    let sent = 0;
    await Promise.allSettled(jobs.map(async (job: Json) => {
      const query = `notification_jobs?id=eq.${job.id}&claim_token=eq.${job.claim_token}`;
      try {
        const [device] = await this.db.rest(`notification_devices?id=eq.${job.device_id}&select=token,user_id,notification_preferences(*)`);
        if (!device || !preferencesAllow(device.notification_preferences, job.kind, job.data) ||
            (mode === 'test' && device.user_id !== this.env('PUSH_TEST_USER_ID'))) {
          await this.db.rest(query, 'PATCH', { status: 'cancelled', last_error: 'recipient_disabled' });
          return;
        }
        const data = { ...job.data, notification_id: job.id };
        if (job.kind === 'episode') {
          data.plugin_id = pluginIds[data.category];
          data.content_id = `tmdb_${data.tmdb_id}_${data.category}`;
        }
        const result = await this.firebase.send(device.token, job.title, job.body, data, job.dedupe_key);
        if (result.unregistered) {
          await this.db.rest(`notification_devices?id=eq.${job.device_id}`, 'DELETE');
          return;
        }
        if (result.ok) { await this.db.rest(query, 'PATCH', { status: 'sent', last_error: null }); sent++; }
        else await this.db.rest(query, 'PATCH', {
          status: transientFcmError(result.status) && job.attempts < 5 ? 'retry' : 'failed',
          available_at: new Date(Date.now() + Math.min(3600, 60 * 2 ** job.attempts) * 1000).toISOString(),
          last_error: `fcm_${result.status}`,
        });
      } catch {
        await this.db.rest(query, 'PATCH', { status: job.attempts < 5 ? 'retry' : 'failed',
          available_at: new Date(Date.now() + 5 * 60000).toISOString(), last_error: 'delivery_failed' });
      }
    }));
    return { sent, claimed: jobs.length, mode };
  }
  async tick() {
    const now = Date.now();
    const scans = await this.db.state('tick:scan');
    if (!scans || now - Date.parse(scans.at) >= 6 * 3600000) {
      await this.scanCatalog();
      await this.db.setState('tick:scan', { at: new Date().toISOString() });
    }
    const release = await this.db.state('tick:release');
    if (!release || now - Date.parse(release.at) >= 3600000) {
      await this.scanRelease();
      await this.scanEpisodes();
      await this.db.setState('tick:release', { at: new Date().toISOString() });
    }
    const day = brasilDate();
    const hour = Number(new Intl.DateTimeFormat('en-GB', { timeZone: 'America/Sao_Paulo', hour: '2-digit', hourCycle: 'h23' }).format(new Date()));
    if (hour >= 18 && (await this.db.state('tick:digest'))?.day !== day && ['test', 'live'].includes(this.env('NOTIFICATIONS_MODE') ?? 'off')) {
      await this.digest();
      await this.db.setState('tick:digest', { day });
    }
    return this.dispatch();
  }
}

export function createHandler(env: Env, fetcher: typeof fetch = fetch) {
  const worker = new NotificationWorker(env, fetcher);
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return reply(405, { error: 'method_not_allowed' });
    if (!await secretMatches(request.headers.get('x-ciney-job-key') ?? '', env('NOTIFICATIONS_JOB_SECRET'))) {
      return reply(401, { error: 'unauthorized' });
    }
    try {
      const { action = 'tick' } = await request.json();
      if (action === 'health') {
        const result = await worker.firebase.send(null, 'Configuração CiNey', 'Validação sem envio.', {}, 'configuration', true);
        return reply(result.ok ? 200 : 503, { configured: result.ok, mode: env('NOTIFICATIONS_MODE') ?? 'off',
          firebase_project: worker.firebase.config().project_id, validation_only: true });
      }
      if (action === 'tick') return reply(200, await worker.tick());
      if (action === 'dispatch') return reply(200, await worker.dispatch());
      if (action === 'scan') return reply(200, { scanned: await worker.scanCatalog() });
      return reply(400, { error: 'invalid_action' });
    } catch (error) {
      const code = error instanceof Error && /^[a-z_0-9]+$/.test(error.message) ? error.message : 'automation_failed';
      return reply(500, { error: code });
    }
  };
}

// Both endpoints authenticate their callers themselves before any database access.
if (typeof Deno !== 'undefined') Deno.serve(createHandler((name) => Deno.env.get(name)));
