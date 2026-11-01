# Revisão do sistema de transmissão — 31/10/2026

## Escopo e resultado

Auditoria do CastLite incorporado ao CiNey mobile: contrato Flutter/Kotlin,
detecção de mídia, relay HTTP/HLS, transporte no WebView, seleção de qualidade,
Google Cast, DLNA, Roku, recuperação e ciclo de vida. A implementação foi lida
como está no checkout, incluindo alterações locais anteriores. Nenhuma correção
de produção foi aplicada nesta auditoria, nem novo APK gerado ou instalado.

Skills AAS: systematic-debugging, code-review-checklist, api-contract-testing,
flutter-expert, lint-and-validate e secrets-management (escopo dos cabeçalhos).

Há defeitos que não são detectados pela suíte existente. Três verificações
diagnósticas adicionais falharam por comportamento incorreto, descritas abaixo.
O registro no Redmi também mostrou uma falha concreta de autorização da fonte.
Isso não estabelece que todos os episódios de buffering tenham a mesma causa.

## Achados por prioridade

### 1. P1 — Credenciais da fonte podem acompanhar recursos de outros hosts

**Evidência por inspeção:** `LocalMediaProxy.kt:195–208` copia Authorization e
Cookie da rota para cada recurso; não compara a origem do recurso com a origem
da mídia que forneceu esses cabeçalhos. `HlsPlaylist.rewrite` aceita recursos
HTTP/HTTPS externos anunciados no manifesto. O Cookie explícito também tem
precedência sobre a consulta ao CookieManager para o endereço efetivamente
requisitado.

**Gatilho:** uma fonte fornece credenciais explícitas e seu manifesto referencia
um CDN/host diferente. **Impacto:** credenciais podem ser enviadas fora de seu
escopo; cookies errados também podem provocar recusa do servidor. Não foi
demonstrado vazamento de uma credencial real no aparelho.

**Correção proposta:** vincular credenciais explícitas à origem correspondente;
obter cookies pelo endereço de destino; permitir compartilhamento entre origens
somente mediante política explícita da integração. Testar com dois servidores
locais e cabeçalhos sintéticos, preservando Referer/Origin exigidos pela fonte.

### 2. P1 — Recusa HTTP 403 termina em recargas sem renovar a fonte

**Evidência real:** no processo do CiNey Teste, entre 22:15:42 e 22:16:26
(horário de São Paulo), o relay registrou vários `GET status=403`, incluindo
playlist e segmentos. A TV informou `IDLE idleReason=4`. Houve três recargas
automáticas às 22:15:43, 22:15:51 e 22:15:59, na posição 1.987.967 ms, seguidas
por novas recusas. Antes disso, o transporte no navegador havia entregue
respostas 200. URLs e credenciais foram omitidas deste relatório.

**Código:** `CastingService.kt:108–128` reutiliza a mesma DetectedVideo, mudando
apenas a posição. `LocalMediaProxy.kt:218–250` tenta o navegador para HLS, mas
não informa a causa HTTP ao mecanismo de recuperação. O erro final apresentado
é genérico. O orçamento de três recargas é respeitado; não é um loop infinito.

**Impacto:** a TV pode repetir carregamento sem que o usuário saiba que a fonte
negou acesso. As evidências não distinguem expiração de URL, restrição de sessão,
política do servidor ou outro bloqueio. O nome do servidor HTTP não prova a
presença de um desafio anti-bot.

**Correção proposta:** propagar categorias de falha sem URL/tokens; distinguir
recusa persistente de falha transitória; oferecer reabertura/resolução legítima
da fonte e troca de servidor preservando a posição, em vez de somente recarregar.

### 3. P2 — Continuação por Range aceita resposta com fim/tamanho incompatível

**Reproduzido em servidor local:** primeira resposta anuncia oito bytes e entrega
`abcd`; a continuação solicitada é `bytes=4-7`. O servidor responde 206 com
`Content-Range: bytes 4-11/12`, o mesmo ETag e oito bytes `efghijkl`.
`RelayHttpSource.stream()` aceita a resposta: o teste que exige IOException
falha porque nenhuma exceção é lançada.

**Código:** `RelayHttpSource.kt:66–87` verifica status, deslocamento inicial e
validador, mas não o fim/total do Content-Range ou o limite restante de bytes.
O loop do relay transmite até EOF, embora seus cabeçalhos tenham sido definidos
a partir da resposta inicial.

**Impacto:** uma resposta incompatível pode entregar bytes além do corpo anunciado
e violar a integridade da retomada, especialmente após interrupções.

**Correção proposta:** validar o intervalo inteiro e o tamanho restante, limitar
a leitura e rejeitar metadados incompatíveis. Manter os testes de truncamento,
validador e Range absoluto que já existem.

### 4. P2 — Recuperação pode perder a posição de seek ou deixar de tentar

**Duas reproduções locais com a classe real PlaybackRecovery:**

- Reprodução em 11 s, seek para 80 s e buffering prolongado: a política decide
  recarregar, mas guarda 11 s em vez dos 80 s solicitados.
- Posição anterior em 99 s de um vídeo de 100 s, seek de volta para 10 s e
  buffering: depois de 50 s a política retorna WAIT em vez de RELOAD, pois
  continua tratando os 99 s antigos como término do filme.

**Código:** `PlaybackRecovery.kt:22–31` atualiza posição somente em PLAYING e
usa essa posição antiga na detecção de término. Os caminhos de seek do controle,
notificação e plugin não comunicam o novo destino à política.

**Impacto:** recarga no ponto errado e, no segundo caso, ausência de recuperação
enquanto o receptor permanecer nesse estado. Não foi necessário provocar esses
cenários na TV do usuário.

**Correção proposta:** registrar o destino de seek explicitamente, distinguir
seek pendente de avanço efetivo e usar término confirmado, sem confundir
buffering com conclusão normal.

### 5. P2 — Retomar pelo controle da TV pode deixar a recuperação desativada

**Evidência por inspeção:** `CastingService.kt:33` pula a política quando
userPaused é true. A flag é alterada por comandos do app, mas não é reconciliada
quando a TV volta a informar PLAYING por uma ação externa.

**Gatilho:** pausar pelo CiNey e retomar pelo controle físico da TV. **Impacto:**
o filme pode voltar, mas uma falha posterior não aciona a recuperação enquanto
essa flag continuar verdadeira. Não foi exercitado em TV física nesta auditoria.

**Correção proposta:** conciliar intenção local e estado confirmado do receptor,
respeitando pausas pendentes e falhas dos comandos.

### 6. P2 — Playlist HLS parcial não recebe reescrita no caminho HTTP direto

**Evidência por inspeção:** `LocalMediaProxy.kt:203–204` repassa Range mesmo para
playlists; `:231` só considera reescrita quando o status é 200. Se o servidor
honrar esse Range e responder 206, o conteúdo é encaminhado sem reescrever URLs
nem aplicar a seleção de qualidade. O caminho pelo navegador já remove Range
para playlists conhecidas, mostrando uma diferença entre os transportes.

**Impacto condicionado:** receptores que sondam listas com Range podem receber
URLs relativas apontando para rotas inexistentes no relay ou acessar a origem
sem os cabeçalhos necessários. Não foi observado 206 de manifesto nos logs
examinados do Redmi.

**Correção proposta:** tratar manifestos completos de forma consistente entre os
transportes; não encaminhar um intervalo parcial como se fosse uma lista local
reescrita. Testar GET/HEAD e origem que respeita Range.

### 7. P2 — Fonte MP4 protegida não tem o mesmo fallback do HLS

**Evidência por inspeção:** `LocalMediaProxy.kt:165,178,218` condiciona o fallback
do navegador à identificação da fonte como HLS. MP4 que retorna 401/403 no
transporte nativo recebe o erro diretamente, mesmo havendo frame de origem.

**Impacto condicionado:** arquivo que toca no navegador pode falhar na TV quando
depende daquela sessão. A suíte atual não cobre esse contrato. O fallback não
deve ser simplesmente habilitado sem tratar Range e o limite de 128 MiB do
transporte em arquivo temporário.

**Correção proposta:** definir suporte explícito para arquivos protegidos com
leitura por intervalos e cancelamento, ou informar a limitação ao usuário.

### 8. P2 — Estado DLNA não acompanha pausa/término/desconexão externos

**Evidência por inspeção:** `DlnaCastTarget.kt:270–282` consulta somente
GetPositionInfo; não consulta o estado de transporte e ignora falhas dessa
consulta. isConnected é uma flag local. PLAYING é atribuído pelo aceite do
comando Play, sem confirmação do início da reprodução.

**Impacto condicionado:** o controle pode continuar indicando reprodução quando
a TV pausou, terminou ou saiu da rede. O watchdog pode recarregar durante uma
pausa externa. No término, a posição próxima do fim apenas faz o watchdog
esperar, e o encerramento por IDLE pode não ocorrer, mantendo serviço e locks.

**Correção proposta:** consultar/assinar estado real do AVTransport, classificar
desconexões e encerrar polling/serviço de forma determinística. Requer teste em
receptor DLNA; o aparelho observado usou Google Cast.

### 9. P2 — Descoberta DLNA não é idempotente e tem corrida com stop

**Evidência por inspeção:** `DlnaDiscovery.kt:48–60` cria um novo UpnpService e
uma thread em cada start, sobrescrevendo upnpService. O botão Buscar Novamente
chama start outra vez. stop limpa somente a referência corrente e não invalida
uma inicialização ainda em andamento.

**Impacto condicionado:** serviços anteriores podem continuar ativos, ou uma
inicialização concluir depois de stop, deixando descoberta e recursos vivos.

**Correção proposta:** controlar os estados parado/iniciando/ativo e usar geração
ou cancelamento para descartar/fechar inicializações obsoletas. Não reproduzido
com uma TV DLNA durante esta revisão.

## Limitações adicionais e decisões de produto

- A seleção máxima que implementei anteriormente considera a resolução declarada,
  mas não consulta as capacidades da TV. Preserva codecs alternativos na maior
  resolução; se nenhum for suportado, não resta uma opção inferior compatível.
  É um risco da seleção atual, não evidência de que o Redmi tenha enviado um
  codec incompatível nesta sessão. Não reintroduzir modo econômico: uma eventual
  revisão deve escolher a maior qualidade compatível com o receptor.
- Fixar a maior resolução remove a adaptação para baixo. Isso atende à preferência
  do usuário, mas não garante fluidez em rede insuficiente. O teste real confirmou
  720p solicitado e novas ocorrências de buffering.
- O fallback JavaScript envia apenas Range explicitamente; não existe política
  configurável de headers/credenciais para fontes entre origens. Não foi possível
  atribuir os 403 reais especificamente a isso. A fonte pode exigir condições que
  o navegador de origem também já não satisfaz.
- O relay cria uma rota por load e mantém seus recursos até close. Recargas e
  playlists ao vivo podem acumular referências. Não foi medida fuga de memória
  nesta auditoria; recomenda-se medir antes de alterar retenção de rotas.
- Não houve ensaio físico de DLNA/Roku, morte do processo, troca de IP, tela
  apagada por longo período ou codec 4K. Os testes não comprovam esses cenários.

## Verificações executadas

| Verificação | Resultado desta auditoria |
| --- | --- |
| `:castlite_engine:testDebugUnitTest` | Suíte existente concluída com sucesso, 88 testes |
| `:castlite_engine:lintDebug` | Sem erros; 29 avisos |
| `node --test CastLite/CastLite/app/src/test/js/media_observer_test.cjs` | 11 testes passaram |
| `flutter analyze --no-pub` em cinemax | Nenhum problema, 75,2 s |
| `flutter test --no-pub test/castlite_bridge_test.dart test/castlite_entrypoints_test.dart test/details_cast_sources_test.dart test/tv_cast_service_test.dart` | 13 testes passaram |
| Três probes JVM adicionais com fontes reais e fixtures sintéticas | Três falhas funcionais esperadas: Range incompatível aceito; seek perde destino; seek de volta do fim não recupera |
| Logs do Redmi via ADB | 720p solicitado na fonte anterior; buffering e, posteriormente, recusas HTTP 403 em outra sessão/fonte |

Os probes foram executados por um init script Gradle temporário adicionando uma
pasta de fontes de teste, sem alterar classes de produção. A suíte regular não
continha essas verificações. As falhas adicionais não devem ser apresentadas
como testes aprovados; seus gatilhos e resultados estão registrados nos achados
3 e 4. Os arquivos temporários foram removidos ao finalizar a auditoria.

## Ordem sugerida de correção

1. Restringir credenciais por origem e tratar recusa de acesso com diagnóstico
   e renovação legítima da fonte, preservando posição.
2. Corrigir validação de Range e estado de seek/pausa da recuperação, adicionando
   os três cenários reproduzidos à suíte permanente.
3. Uniformizar playlists e arquivos protegidos nos dois transportes.
4. Corrigir descoberta/estado DLNA e validar Google Cast, DLNA e Roku em aparelhos.

Único arquivo permanente criado nesta auditoria: este relatório. As alterações
de qualidade e os demais arquivos já modificados no checkout foram preservados.
Nenhuma conclusão de que o sistema inteiro está livre de regressões é sustentada
pelas verificações realizadas; os achados acima permanecem pendentes.
