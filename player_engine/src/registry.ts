import { readFile } from 'node:fs/promises';

export type ResolveRequest = {
  type: 'movie' | 'series'; tmdbId?: string; imdbId?: string;
  season?: number; episode?: number;
};
export type Provider = {
  id: string; name: string; enabled: boolean; kind: 'embed' | 'native';
  priority: number; idTypes: ('tmdb' | 'imdb')[];
  movie?: string; episode?: string; documentation: string;
  authorizedDirect?: boolean; mimeType?: string;
};
export type Registry = { version: 1; providers: Provider[] };

const embedHosts = new Set(['myembed.biz', 'superflixapi.quest', 'playerflix.ink']);

function validateTemplate(template: string, kind: Provider['kind']): void {
  const placeholders = template.match(/\{[^}]+\}/g) ?? [];
  if (placeholders.some(value => !['{id}', '{season}', '{episode}'].includes(value))) {
    throw new Error('Invalid provider template placeholder');
  }
  const url = new URL(template.replace(/\{(id|season|episode)\}/g, '1'));
  if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password) {
    throw new Error('Providers require HTTP(S) URLs without embedded credentials');
  }
  if (kind === 'native' && [...embedHosts].some(host => url.hostname === host || url.hostname.endsWith(`.${host}`))) {
    throw new Error('Documented embed providers cannot be configured as native media');
  }
}

export function validateRegistry(value: unknown): Registry {
  if (!value || typeof value !== 'object') throw new Error('Invalid registry');
  const registry = value as Registry;
  if (registry.version !== 1 || !Array.isArray(registry.providers) || registry.providers.length > 32) {
    throw new Error('Unsupported registry version or provider count');
  }
  const ids = new Set<string>();
  for (const provider of registry.providers) {
    if (!provider || typeof provider.id !== 'string' || !/^[a-z0-9-]{1,40}$/.test(provider.id) || ids.has(provider.id) ||
        typeof provider.name !== 'string' || !provider.name.trim() || provider.name.length > 80 ||
        typeof provider.enabled !== 'boolean' || !['embed', 'native'].includes(provider.kind) ||
        !Number.isInteger(provider.priority) || provider.priority < 0 ||
        !Array.isArray(provider.idTypes) || !provider.idTypes.length ||
        provider.idTypes.some(type => !['tmdb', 'imdb'].includes(type)) ||
        typeof provider.documentation !== 'string' ||
        (!provider.movie && !provider.episode)) {
      throw new Error('Invalid provider configuration');
    }
    ids.add(provider.id);
    if (provider.kind === 'native' &&
        (provider.authorizedDirect !== true ||
         !['video/mp4', 'application/vnd.apple.mpegurl', 'application/x-mpegURL',
           'application/dash+xml', 'video/webm'].includes(provider.mimeType ?? ''))) {
      throw new Error('Native sources require explicit authorization and media type');
    }
    for (const template of [provider.movie, provider.episode]) {
      if (template !== undefined) {
        if (typeof template !== 'string') throw new Error('Invalid provider template');
        validateTemplate(template, provider.kind);
      }
    }
  }
  return registry;
}

export async function loadRegistry(path: string): Promise<Registry> {
  return validateRegistry(JSON.parse(await readFile(path, 'utf8')));
}

export function resolveSources(registry: Registry, request: ResolveRequest) {
  return registry.providers.filter(provider => provider.enabled).flatMap(provider => {
    const id = request.tmdbId && provider.idTypes.includes('tmdb') ? request.tmdbId :
      request.type === 'movie' && request.imdbId && provider.idTypes.includes('imdb') ? request.imdbId : null;
    const template = request.type === 'movie' ? provider.movie : provider.episode;
    if (!id || !template) return [];
    const url = template.replaceAll('{id}', encodeURIComponent(id))
      .replaceAll('{season}', String(request.season ?? ''))
      .replaceAll('{episode}', String(request.episode ?? ''));
    return [{
      providerId: provider.id, server: provider.name, kind: provider.kind, url,
      priority: provider.priority, quality: 'Conforme o fornecedor',
      mimeType: provider.mimeType ?? 'text/html', availability: 'unverified',
      capabilities: {
        nativeControls: provider.kind === 'native',
        iframeRequired: provider.kind === 'embed',
      },
    }];
  }).sort((a, b) => a.priority - b.priority);
}
