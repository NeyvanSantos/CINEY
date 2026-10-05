# 🔌 Regra 05: Motor de Plugins, Extensões & Provedores

---

## 1. Princípio do Desacoplamento

O CineMax opera como um agregador de catálogo modular através do `plugin_engine/`.  
A camada de apresentação (telas de catálogo, busca e player) **NUNCA** deve conter lógica proprietária de scrapers de sites ou parsers de streams. Toda fonte deve implementar os contratos definidos.

---

## 2. Contratos & Interfaces Oficiais

- **Contrato Base:** `lib/plugin_engine/contracts/plugin_interface.dart`
- **Gerenciador Central:** `lib/plugin_engine/manager/plugin_manager.dart`
- **Resolução de Streams:** `lib/plugin_engine/runtime/stream_resolver.dart`
- **Modelos:**
  - `ContentItem` / `ContentDetail` (dados do filme/série)
  - `StreamSource` (URLs de reprodução HLS `.m3u8`, MP4 ou embed iframe)
  - `PluginManifest` (metadados do plugin: id, nome, versão, categorias suportadas)

---

## 3. Resolução Segura de Streams

1. Se um plugin retornar uma URL direta (`.m3u8` ou `.mp4`), certifique-se de preencher os cabeçalhos HTTP necessários (ex.: `User-Agent`, `Referer`) no objeto `StreamSource`.
2. Se retornar um embed/iframe, o player utilizará a `WebViewBridge` ou o `WebCastServer` para contornar proteções.
3. Tratamento de falhas: Se um servidor ou provedor falhar, o `StreamResolver` deve tentar o próximo servidor de fallback de maneira transparente antes de retornar erro para o usuário.
