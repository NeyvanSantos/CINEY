# Transmissão Nativa Autônoma (Standalone Cast)

## Objetivo
Tornar a transmissão para TV (Chromecast, DLNA e WebCast) 100% autônoma e interna no Cinemax, eliminando qualquer dependência de aplicativos externos (como Web Video Caster), utilizando sniffer de mídia em segundo plano e proxy de stream com base na arquitetura do `crx-webcast-reloaded`.

## Tarefas
- [x] 1. Criar `MediaStreamSniffer`: Interceptador headless em segundo plano para extrair URLs diretas (.m3u8, .mp4) e headers de fontes Embed → Concluído: Implementado com hooks JS (fetch/xhr/DOM) e delegado de navegação.
- [x] 2. Evoluir `WebCastServer`: Adicionar mini HLS-Proxy streaming com suporte a Range requests e reescrita de Referer/CORS + Player Clappr/HTML5 para WebCast → Concluído: Endpoint `/stream` com proxy transparente e HLS.js no receptor de TV.
- [x] 3. Atualizar `UniversalCastService`: Integrar proxy de stream e suporte unificado a Chromecast, DLNA e WebCast sem depender de players externos → Concluído: `connectAndCast` com roteamento automático de proxy e protocolo HLS para TVs.
- [x] 4. Atualizar `CastDialog`: Remover dependência do Web Video Caster, adicionar feedback de extração de stream e seleção unificada de TV → Concluído: Diálogo moderno com Chromecast direto, Smart TVs DLNA e WebCast.
- [x] 5. Ajustar ponte nativa Android (`MainActivity.kt` e `NativeCastBridge`): Garantir compatibilidade máxima de headers e URLs diretas no Google Cast SDK → Concluído: Reconhecimento de rotas `/stream`, `/hls/` e novos formatos de mídia.

## Concluído Quando
- [x] Transmissão de conteúdos do SuperFlix e EmbedMovies ocorre diretamente para Chromecast, DLNA e WebCast sem requerer a instalação de apps de terceiros.
- [x] O código-fonte permanece sólido, organizado, tipado e profissional.
