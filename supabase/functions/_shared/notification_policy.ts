export const categories = ['movie', 'series', 'anime', 'dorama'] as const;
export type Category = typeof categories[number];
export type Json = Record<string, any>;

export function brasilDate(now = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(now);
  const part = (name: string) => parts.find((p) => p.type === name)!.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

export function catalogItem(row: Json, category: Category, now = new Date()): Json | null {
  const id = Number(row.id);
  const title = String(row.title ?? row.name ?? '').trim();
  const date = String(row.release_date ?? row.first_air_date ?? '');
  const age = now.getTime() - Date.parse(date + 'T00:00:00Z');
  if (!Number.isSafeInteger(id) || id <= 0 || !title || !Number.isFinite(age) ||
      age < 0 || age > 90 * 86400000) return null;
  return { key: `${category}:${id}`, category, tmdb_id: id, title: title.slice(0, 500) };
}

export function preferencesAllow(prefs: Json | null, kind: string, data: Json): boolean {
  if (!prefs || !prefs.enabled) return false;
  if (kind === 'app_update') return prefs.app_updates === true;
  if (kind === 'episode') return prefs.episodes === true && prefs[data.category === 'movie' ? 'movies' : data.category] === true;
  if (kind !== 'digest') return false;
  return String(data.categories ?? '').split(',').every((c) =>
    categories.includes(c as Category) && prefs[c === 'movie' ? 'movies' : c] === true);
}

export function digestFor(items: Json[], prefs: Json): { body: string; categories: string } | null {
  if (!prefs.enabled) return null;
  const selected = categories.filter((c) => prefs[c === 'movie' ? 'movies' : c] === true);
  const names: Record<Category, string> = { movie: 'filmes', series: 'séries', anime: 'animes', dorama: 'doramas' };
  const present = selected.filter((c) => items.some((i) => i.category === c));
  if (!present.length) return null;
  return {
    body: present.map((c) => `${items.filter((i) => i.category === c).length} ${names[c]}`).join(', ') +
      ' entre as novidades do catálogo. Abra o CiNey para conferir.',
    categories: present.join(','),
  };
}

export function latestMobileRelease(releases: Json[]): Json | null {
  if (!Array.isArray(releases)) return null;
  return releases.filter((r) => !r.draft && !r.prerelease && /^v\d+\.\d+\.\d+$/.test(r.tag_name) &&
    r.assets?.some((a: Json) => a.name === `CiNey-${r.tag_name}.apk` && a.state === 'uploaded' && a.size > 0))
    .sort((a, b) => {
      const av = a.tag_name.slice(1).split('.').map(Number);
      const bv = b.tag_name.slice(1).split('.').map(Number);
      for (let i = 0; i < 3; i++) if (av[i] !== bv[i]) return bv[i] - av[i];
      return 0;
    })[0] ?? null;
}

export function newerVersion(tag: string, previous: string): boolean {
  if (!/^v\d+\.\d+\.\d+$/.test(tag) || !/^v\d+\.\d+\.\d+$/.test(previous)) return false;
  const a = tag.slice(1).split('.').map(Number);
  const b = previous.slice(1).split('.').map(Number);
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] > b[i];
  return false;
}

export function episodeIdentity(row: Json): string | null {
  const episode = row.last_episode_to_air;
  if (!episode || !Number.isInteger(episode.season_number) || episode.season_number < 1 ||
      !Number.isInteger(episode.episode_number) || episode.episode_number < 1 ||
      typeof episode.air_date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(episode.air_date) ||
      !Number.isFinite(Date.parse(episode.air_date)) ||
      episode.air_date > new Date().toISOString().slice(0, 10)) return null;
  return `${episode.season_number}:${episode.episode_number}`;
}

export function transientFcmError(status: number): boolean {
  return status === 429 || status >= 500;
}
