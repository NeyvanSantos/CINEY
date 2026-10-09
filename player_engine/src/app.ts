import Fastify from 'fastify';
import { loadRegistry, resolveSources, type Registry, type ResolveRequest } from './registry.js';

export function createApp(options: { registryPath?: string; registry?: Registry; logger?: boolean } = {}) {
  const app = Fastify({
    logger: options.logger ?? false, bodyLimit: 4096,
    ajv: { customOptions: { coerceTypes: false, removeAdditional: false } },
  });
  const registry = () => options.registry ? Promise.resolve(options.registry) :
    loadRegistry(options.registryPath ?? 'config/providers.json');

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof Error && ('validation' in error ||
        ('statusCode' in error && error.statusCode === 400))) {
      return reply.code(400).send({ error: { code: 'INVALID_REQUEST', message: 'Informe tipo, ID e episódio válidos.' } });
    }
    request.log.error({ code: 'REGISTRY_UNAVAILABLE' }, 'Provider configuration unavailable');
    return reply.code(503).send({ error: { code: 'REGISTRY_UNAVAILABLE', message: 'Configuração de provedores indisponível.' } });
  });

  app.get('/health', async () => {
    const current = await registry();
    return { status: 'ok', apiVersion: 1, providers: current.providers.filter(p => p.enabled).length };
  });
  app.get('/v1/providers', async () => ({
    apiVersion: 1, providers: (await registry()).providers.map(({ id, name, kind, enabled, documentation }) =>
      ({ id, name, kind, enabled, documentation })),
  }));
  app.post<{ Body: ResolveRequest }>('/v1/resolve', {
    schema: {
      body: {
        type: 'object', additionalProperties: false, required: ['type'],
        properties: {
          type: { enum: ['movie', 'series'] },
          tmdbId: { type: 'string', pattern: '^[1-9][0-9]{0,11}$' },
          imdbId: { type: 'string', pattern: '^tt[0-9]{7,10}$' },
          season: { type: 'integer', minimum: 0, maximum: 10000 },
          episode: { type: 'integer', minimum: 1, maximum: 100000 },
        },
        anyOf: [{ required: ['tmdbId'] }, { required: ['imdbId'] }],
        allOf: [{
          if: { properties: { type: { const: 'series' } } },
          then: { required: ['tmdbId', 'season', 'episode'] },
          else: { not: { anyOf: [{ required: ['season'] }, { required: ['episode'] }] } },
        }],
      },
    },
  }, async (request, reply) => {
    const sources = resolveSources(await registry(), request.body);
    if (!sources.length) {
      return reply.code(404).send({ error: { code: 'NO_SOURCES', message: 'Nenhum provedor habilitado para este conteúdo.' } });
    }
    return { apiVersion: 1, sources };
  });
  return app;
}
