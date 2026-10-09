# CINEY Player Engine — serviço opcional

Registro de fontes para a versão TV. Node.js 22 ou superior, TypeScript e Fastify; sem banco, chave ou serviço pago. O serviço devolve endereços e capacidades, nunca baixa nem retransmite o vídeo. Os players dos provedores continuam responsáveis pelo conteúdo, disponibilidade e eventuais restrições.

## Executar no Windows

Na raiz do repositório, em PowerShell:

```powershell
Set-Location player_engine
npm ci
npm run build
npm start
```

Padrão: `http://127.0.0.1:8787`. Para a TV acessar o computador na mesma rede:

```powershell
$env:HOST = '0.0.0.0'
$env:PORT = '8787'
npm start
```

Use o IP local do computador no app, nunca `localhost` da TV. O serviço é destinado a uma rede local confiável: não possui autenticação e não deve ser exposto diretamente à Internet. Se o Windows bloquear a porta, permita o processo Node apenas na rede privada. Ctrl+C encerra o serviço.

```powershell
Invoke-RestMethod http://127.0.0.1:8787/health
Invoke-RestMethod http://127.0.0.1:8787/v1/providers
$body = @{ type = 'series'; tmdbId = '1396'; season = 1; episode = 1 } | ConvertTo-Json
Invoke-RestMethod http://127.0.0.1:8787/v1/resolve -Method Post -ContentType 'application/json' -Body $body
```

O app só consulta o serviço na TV quando compilado com `--dart-define=CINEY_PLAYER_ENGINE_URL=http://IP_DO_PC:8787`. Sem essa opção, usa as fontes locais existentes. Se houver falha de conexão ou protocolo, também usa as fontes locais e registra `TV_ENGINE`. Uma resposta explícita `NO_SOURCES` é respeitada, sem reativar os provedores desabilitados.

## Contrato v1

| Rota | Resultado |
| --- | --- |
| `GET /health` | Estado do serviço, versão da API e quantidade de provedores habilitados; não mede reprodução. |
| `GET /v1/providers` | Identidade, tipo, documentação e estado de cada provedor. |
| `POST /v1/resolve` | Fontes ordenadas por prioridade para filme ou episódio. |

Filme: `{"type":"movie","tmdbId":"27205"}` ou `{"type":"movie","imdbId":"tt1375666"}`. Se ambos forem informados, TMDB tem preferência. Série: `{"type":"series","tmdbId":"1396","season":1,"episode":1}`. IMDb isolado não resolve episódios. Temporada zero permite especiais; episódio começa em 1. IDs são strings, sem coerção de números.

Cada fonte retorna `providerId`, `server`, `kind` (`embed` ou `native`), `url`, `mimeType`, `priority`, `quality`, `availability: "unverified"` e `capabilities`. `iframeRequired` e `nativeControls` informam qual integração usar; não prometem disponibilidade ou codec compatível.

Erros: `400 INVALID_REQUEST`, `404 NO_SOURCES`, `503 REGISTRY_UNAVAILABLE`. O app mantém os controles de recuperação. O serviço valida entradas, mas não testa títulos nos provedores nem extrai mídia.

## Alterar fontes sem recompilar o app

```powershell
Copy-Item config/providers.json providers.local.json
$env:CINEY_PROVIDERS_FILE = 'providers.local.json'
npm start
```

O arquivo é relido a cada requisição; edite `enabled`, `priority`, nome ou templates. Mudanças aparecem na próxima resolução/abertura do título. A sessão já em reprodução continua com sua fonte. Use gravação atômica do JSON para evitar leituras parciais; uma configuração inválida produz 503.

O nome `server` é usado pelo histórico existente: mantenha-o estável para preservar a preferência. A escolha explícita/salva do usuário prevalece; sem ela, o comportamento existente prioriza EmbedMovies quando disponível. `priority` ordena a lista e alternativas.

Templates aceitam `{id}`, `{season}` e `{episode}`. Provedores `native` exigem `authorizedDirect: true` e MIME de MP4, WebM, HLS ou DASH. Essa declaração registra a responsabilidade do administrador; não é uma verificação automática de direitos. Endereços conhecidos de embed não podem ser declarados nativos. HTTP(S) é obrigatório; credenciais na URL são rejeitadas. Não há proxy, remoção de DRM nem acesso a cookies do usuário pelo backend.

Para testar somente reprodução nativa com o trailer público da Blender Foundation:

```powershell
$env:CINEY_PROVIDERS_FILE = 'config/providers.sintel-test.json'
npm start
```

**Configuração de teste:** qualquer filme aberto aponta para o mesmo trailer Sintel; séries não têm fontes. Volte para `config/providers.json` para o catálogo normal. Não use essa configuração como catálogo de produção.

## Verificação

```powershell
npm run build
npm test
npm run test:integration
```

Os testes locais cobrem validação, filmes/episódios, atualização do registro, fontes desabilitadas, contrato nativo e listener HTTP real. A integração de rede pede somente 32 bytes do trailer Sintel e verifica HTTP 206, `video/mp4` e assinatura MP4. Não decodifica vídeo nem valida uma televisão.

Arquitetura do app, APK e pendências: [documentação TV](../docs/tv-player-engine.md).
