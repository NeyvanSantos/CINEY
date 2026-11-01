# Aplicação do plano de correção da transmissão

Data: 31/10/2026. Referências: [plano aprovado](plano-correcao-transmissao-2026-10-31.md)
e [auditoria](revisao-transmissao-2026-10-31.md).

## Comportamento implementado

- Retomadas HTTP validam início, fim, total, comprimento e validador. A leitura
  é limitada ao corpo anunciado. O intervalo inicial também deve corresponder
  ao solicitado pelo receptor; resposta incompatível é rejeitada.
- Credenciais explícitas ficam na origem correspondente, considerando esquema,
  host e porta. Redirecionamentos são limitados e reaplicam a política; cookies
  de um CDN são obtidos para seu próprio endereço. Downgrade de HTTPS e URLs com
  credenciais embutidas não são seguidos pelo relay.
- Cabeçalhos herdados de uma página embed não são automaticamente convertidos
  em credenciais de uma mídia em outra origem. Os nomes são normalizados para
  que a captura mais recente prevaleça, sem duplicatas por capitalização.
- O transporte de navegador usa cookies entre origens apenas quando o Android
  detecta cookies para o destino; sem isso, mantém o comportamento same-origin.
  CORS, cookies de terceiros, sessão da fonte e restrições do provedor continuam
  sendo respeitados. Nenhum cabeçalho de credencial é exportado ao JavaScript
  para configurar esse comportamento.
- Manifestos conhecidos não recebem Range do receptor no caminho direto. Se
  uma resposta parcial revelar uma playlist antes desconhecida, o relay refaz
  a requisição completa; uma lista ainda parcial é rejeitada. O navegador
  também não encaminha lista parcial como manifesto local válido.
- Seeks explícitos conservam o destino pendente até confirmação ou recuperação.
  A posição informada durante buffering pode atualizar o ponto de retomada.
  Buffering próximo ao fim não é tratado como conclusão confirmada.
- Pausa confirmada e retomada externa são conciliadas. Um comando de pausa não
  confirmado não desativa o monitoramento indefinidamente. O relógio de progresso
  continua sendo atualizado durante pausas reais.
- Uma recusa 401/403 que persiste sem avanço do filme suspende as recargas e
  oferece **Voltar à fonte**. Reabrir um embed usa o fluxo existente de detecção;
  link direto recusado informa a necessidade de obter outra fonte ou trocar o
  servidor. Posição/episódio são preservados quando o protocolo permite.
- Um erro isolado de segmento não interrompe reprodução que continua avançando.
  A espera por ação sobre uma fonte recusada é limitada a três minutos; os
  controles de reprodução ficam desabilitados nesse estado e Parar fica disponível.
- Eventos de relay e callbacks de carregamentos antigos não atualizam a nova
  geração da transmissão. O destino de seek é comunicado pelo controle, serviço
  e canal Flutter/Kotlin de forma consistente.
- Google Cast mantém proteção de geração no carregamento. Roku aguarda estado
  consultado para confirmar reprodução e reconhece falhas repetidas de consulta.
  Nos dois protocolos, respostas obsoletas não encerram a tentativa atual.
- DLNA consulta o estado real do AVTransport, limita consultas concorrentes e
  descarta callbacks antigos. Buscar novamente reutiliza a descoberta ativa;
  uma inicialização concluída depois de stop é encerrada.
- Quando DLNA informa que a consulta de estado não é suportada, o app avisa e
  evita recuperação automática baseada em estado incompleto. Avanço de posição
  ainda pode confirmar reprodução. Nesse receptor, encerramento deve ser feito
  pelo usuário quando não houver informação suficiente sobre o término.
- Polling dos adaptadores não Google é encerrado ao liberar o serviço. Tempos
  e orçamentos gerais de recuperação foram preservados.
- A qualidade máxima continua selecionada, sem modo econômico. O controle mostra
  a resolução **solicitada**, sem afirmar uma resolução efetivamente decodificada
  que o protocolo não comprovou. O título real substitui o texto genérico.

## Arquivos desta aplicação

Caminhos abaixo de `CastLite/CastLite/app/src/`, salvo indicação diferente:

| Grupo | Arquivos |
| --- | --- |
| Transporte | `main/java/com/example/castlite/RelayHttpSource.kt`, `RelayHeaderPolicy.kt` (novo), `LocalMediaProxy.kt`, `FrameMediaTransport.kt` |
| Sessão/recuperação | `main/java/com/example/castlite/PlaybackRecovery.kt`, `PlaybackIntent.kt` (novo), `SourceAccessGuard.kt` (novo), `CastingService.kt`, `CastSessionEvents.kt` |
| Controle e entrada | `main/java/com/example/castlite/MainActivity.kt`, `RemoteControlActivity.kt` |
| Protocolos | `main/java/com/example/castlite/casting/CastTarget.kt`, `DiscoveryLifecycle.kt` (novo), `dlna/DlnaDiscovery.kt`, `dlna/DlnaCastTarget.kt`, `google/GoogleCastTarget.kt`, `roku/RokuCastTarget.kt` |
| Navegador/recursos | `main/assets/media_observer.js`, `main/res/layout/activity_cast_control.xml`, `main/res/values/strings.xml` |
| Plugin Android | `cinemax/packages/castlite_engine/android/src/main/kotlin/com/ciney/castlite/CastLitePlugin.kt` |
| Testes | `test/java/com/example/castlite/RelayHttpSourceTest.kt`, `PlaybackRecoveryTest.kt`, `RelayHeaderPolicyTest.kt` (novo), `CastSessionPolicyTest.kt` (novo), `DiscoveryLifecycleTest.kt` (novo); `test/js/media_observer_test.cjs` |
| Documentação | Este registro, plano aprovado e documentação de integração |

As alterações anteriores de qualidade em HlsPlaylist, remoção do menu econômico
e demais mudanças existentes no checkout foram preservadas. Nenhuma alteração
de catálogo, autenticação da conta, banco de dados ou player do host TV foi
necessária nesta aplicação. Nenhuma dependência foi adicionada.

## Testes e revisão

- `:castlite_engine:testDebugUnitTest`: **106 testes passaram**.
- `:castlite_engine:lintDebug`: **zero erros e 29 avisos**.
- `node --test CastLite/CastLite/app/src/test/js/media_observer_test.cjs`:
  **12 testes passaram**.
- `flutter analyze --no-pub` em `cinemax`: **nenhum problema** (112,5 s).
- `flutter test --no-pub test/castlite_bridge_test.dart test/castlite_entrypoints_test.dart test/details_cast_sources_test.dart test/tv_cast_service_test.dart`:
  **13 testes passaram**.
- Verificação de whitespace pelo Git: sem falhas; avisos de normalização CRLF
  não representam erros de código.

Os defeitos centrais foram verificados por testes que falharam antes das
correções: intervalos incompatíveis, posições durante buffering, política de
pausa, recusa persistente, escopo de credenciais, descoberta duplicada e estados
DLNA. O novo teste de credenciais do navegador também falhou antes da alteração
JavaScript. Testes complementares de redirecionamento e integridade foram
adicionados durante a implementação. Proteções dependentes do SDK e UI exigem
ensaios de integração; compilar e passar testes locais não comprova TV física.

Skills AAS utilizadas: brainstorming para o desenho já aprovado;
systematic-debugging, test-driven-development, secrets-management,
api-contract-testing, flutter-expert, code-review-checklist e lint-and-validate
na implementação e revisão.

## Limites preservados e pendências

1. Os adaptadores atuais não oferecem uma informação confiável e universal de
   codecs/resoluções suportados pela TV. Quando esse suporte é desconhecido,
   continua valendo a maior resolução declarada da fonte. Não foi implementado
   um fallback que adivinhe incompatibilidade a partir de um erro genérico.
2. Qualidade máxima pode carregar em rede insuficiente. Não há transcodificação,
   aumento artificial de qualidade nem redução silenciosa por economia.
3. MP4 protegido que exige exclusivamente o navegador recebe a ação clara de
   reabrir/trocar fonte. Não foi ativado um fetch irrestrito do filme inteiro,
   nem aumentado o limite de 128 MiB por recurso para esconder essa limitação.
4. Roku continua com seek aproximado. Dispositivos DLNA sem consulta de estado
   têm limitação explícita de recuperação e de confirmação de término.
5. Ensaios físicos da nova compilação precisam ser registrados: reprodução,
   pausa/retomada na TV, seek durante buffering, troca de servidor, tela apagada,
   falha de rede e liberação de recursos. Não foram declarados aprovados nesta
   entrega apenas com base nos testes automatizados.

## Compilação de teste e reversão

O usuário já autorizou a compilação/instalação local no Redmi. A atualização usa
o script existente com `-Target mobile -Offline` e o pacote isolado
`com.ciney.app.castlite_test`; não substitui `com.ciney.app` nem publica release.

Referência anterior preservada em
`.work/cast-reference/CiNey-Teste-antes-das-correcoes.apk`, SHA-256
`0DFD4752EE813BD42B01F08111D8FF8D00C744CC35A1A56776D283FA9883ACDC`.

Nova compilação e instalação concluídas:

- Build local: sucesso em 1 min 32 s, sem publicação externa.
- APK: `outputs/CiNey-CastLite-BlueStacks-teste.apk`, 227.813.380 bytes.
- SHA-256: `20881DA0C1CA9AB72C605BE2DD139C1ABFB6346D55E9FE053EDEAA6133BB5767`.
- Assinatura v2 verificada, um assinante. Pacote `com.ciney.app.castlite_test`,
  versão `1.0.47-teste-local` / código 44; ARM64, ARMv7 e x86_64.
- Conteúdo do APK conferido: políticas de acesso/cabeçalhos/pausa presentes,
  observador JS atualizado e preferência `economy_opt_in` ausente.
- ADB `install -r`: **Success**, preservando os dados do pacote de teste.
- Redmi conectado por rede: atualização registrada em 31/10/2026 às 22:55:53;
  processo do CiNey Teste iniciado e nenhum erro fatal retornado na leitura de
  AndroidRuntime após abrir. O pacote principal `com.ciney.app` permanece instalado.

Instalação e inicialização não equivalem à aprovação da reprodução na TV. Os
ensaios físicos listados acima continuam pendentes para esta compilação.
