import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { validateRegistry } from '../src/registry.js';

// Blender Foundation's public Sintel trailer. This checks HTTP, not a decoder/TV.
const media = 'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4';
test('public authorized MP4 resolves as native and responds with media bytes', async () => {
  const registry = validateRegistry({ version: 1, providers: [{
    id: 'sintel-test', name: 'Sintel trailer (test)', enabled: true,
    kind: 'native', priority: 1, idTypes: ['tmdb'], authorizedDirect: true,
    mimeType: 'video/mp4', movie: media, documentation: 'https://durian.blender.org/',
  }] });
  const app = createApp({ registry });
  try {
    const resolved = await app.inject({ method: 'POST', url: '/v1/resolve', payload: { type: 'movie', tmdbId: '1' } });
    assert.equal(resolved.json().sources[0].kind, 'native');
    const response = await fetch(resolved.json().sources[0].url, {
      headers: { Range: 'bytes=0-31' }, signal: AbortSignal.timeout(20000),
    });
    try {
      assert.equal(response.status, 206);
      assert.match(response.headers.get('content-type') ?? '', /video\/mp4/);
      const bytes = new Uint8Array(await response.arrayBuffer());
      assert.equal(bytes.length, 32);
      assert.equal(Buffer.from(bytes.slice(4, 8)).toString(), 'ftyp');
    } finally { await response.body?.cancel().catch(() => undefined); }
  } finally { await app.close(); }
});
