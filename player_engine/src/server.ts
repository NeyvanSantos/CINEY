import { createApp } from './app.js';
const app = createApp({ registryPath: process.env.CINEY_PROVIDERS_FILE, logger: true });
try {
  await app.listen({ host: process.env.HOST ?? '127.0.0.1', port: Number(process.env.PORT ?? 8787) });
} catch (error) {
  app.log.error(error);
  process.exitCode = 1;
}
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, async () => { await app.close(); });
}
