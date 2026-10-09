import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.js';
import { loadRegistry, validateRegistry } from '../src/registry.js';

const registry = await loadRegistry('config/providers.json');

test('health and provider listing do not claim media availability', async () => {
  const app = createApp({ registry });
  try {
    assert.equal((await app.inject('/health')).json().providers, 2);
    const providers = (await app.inject('/v1/providers')).json();
    assert.equal(providers.apiVersion, 1);
    assert.equal(providers.providers[1].kind, 'embed');
  } finally { await app.close(); }
});

for (const [payload, path] of [
  [{ type: 'movie', tmdbId: '27205' }, '/filme/27205'],
  [{ type: 'movie', imdbId: 'tt1375666' }, '/filme/tt1375666'],
  [{ type: 'series', tmdbId: '1396', season: 0, episode: 1 }, '/serie/1396/0/1'],
] as const) {
  test(`documented embed resolution: ${path}`, async () => {
    const app = createApp({ registry });
    try {
      const response = await app.inject({ method: 'POST', url: '/v1/resolve', payload });
      assert.equal(response.statusCode, 200);
      const sources = response.json().sources;
      assert.equal(sources.length, 2);
      assert.equal(sources[1].url, `https://myembed.biz${path}`);
      for (const source of sources) {
        assert.equal(source.kind, 'embed');
        assert.equal(source.availability, 'unverified');
        assert.equal(source.capabilities.nativeControls, false);
      }
    } finally { await app.close(); }
  });
}

test('malformed and ambiguous requests are rejected without coercion', async () => {
  const app = createApp({ registry });
  try {
    for (const payload of [
      { type: 'movie' }, { type: 'movie', tmdbId: 1 },
      { type: 'movie', tmdbId: '../1' }, { type: 'movie', tmdbId: '1', url: 'https://evil.test' },
      { type: 'movie', tmdbId: '1', season: 1 },
      { type: 'series', imdbId: 'tt1375666', season: 1, episode: 1 },
      { type: 'series', tmdbId: '1' }, { type: 'series', tmdbId: '1', season: 1, episode: 0 },
    ]) {
      const response = await app.inject({ method: 'POST', url: '/v1/resolve', payload });
      assert.equal(response.statusCode, 400, JSON.stringify(payload));
      assert.equal(response.json().error.code, 'INVALID_REQUEST');
    }
  } finally { await app.close(); }
});

test('registry hot reload respects disabled sources and invalid config', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'ciney-engine-'));
  const registryPath = join(directory, 'providers.json');
  const app = createApp({ registryPath });
  const resolve = () => app.inject({ method: 'POST', url: '/v1/resolve', payload: { type: 'movie', tmdbId: '1' } });
  try {
    await writeFile(registryPath, JSON.stringify(registry));
    assert.equal((await resolve()).statusCode, 200);
    await writeFile(registryPath, JSON.stringify({ version: 1, providers: registry.providers.map(p => ({ ...p, enabled: false })) }));
    assert.equal((await resolve()).json().error.code, 'NO_SOURCES');
    await writeFile(registryPath, 'invalid');
    assert.equal((await resolve()).statusCode, 503);
  } finally { await app.close(); await rm(directory, { recursive: true }); }
});

test('native sources require explicit media declaration and never use embed hosts', () => {
  const provider = { ...registry.providers[0]!, kind: 'native', authorizedDirect: true, mimeType: 'video/mp4' };
  assert.throws(() => validateRegistry({ version: 1, providers: [provider] }));
  const direct = { ...provider, movie: 'https://media.example.test/{id}.mp4', episode: undefined };
  assert.equal(validateRegistry({ version: 1, providers: [direct] }).providers[0]!.kind, 'native');
  assert.throws(() => validateRegistry({ version: 1, providers: [{ ...direct, authorizedDirect: false }] }));
  assert.throws(() => validateRegistry({ version: 1, providers: [{ ...direct, mimeType: 'text/html' }] }));
});

test('unsafe templates, duplicate ids and unsupported versions are rejected', () => {
  const provider = registry.providers[0]!;
  for (const movie of ['file:///test', 'https://user:secret@example.test/{id}', 'https://example.test/{unknown}']) {
    assert.throws(() => validateRegistry({ version: 1, providers: [{ ...provider, movie }] }));
  }
  assert.throws(() => validateRegistry({ version: 1, providers: [provider, provider] }));
  assert.throws(() => validateRegistry({ version: 2, providers: [] }));
});

test('actual HTTP listener resolves sources without forwarding video', async () => {
  const app = createApp({ registry });
  try {
    const address = await app.listen({ host: '127.0.0.1', port: 0 });
    const response = await fetch(`${address}/v1/resolve`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ type: 'movie', tmdbId: '1' }),
    });
    assert.equal(response.status, 200);
    const result = await response.json() as { sources: { kind: string }[] };
    assert.equal(result.sources[0]!.kind, 'embed');
    assert.equal((await fetch(`${address}/proxy?url=https://example.test`)).status, 404);
  } finally { await app.close(); }
});
