# Teste da transmissão no Redmi — 31/10/2026

## Resultado

**A transmissão não está aprovada quanto à estabilidade dessa fonte.** Qualidade
solicitada, pausa, retomada e os saltos de 10 s funcionaram, mas a fonte começou
a negar acesso com HTTP 403. O aviso de recusa apareceu; reabrir a fonte não
produziu uma nova sessão estável confirmada durante este ensaio.

Não houve alteração de código de produção neste teste.

## Ambiente e método

- Redmi Note 13 Pro 5G, conectado por ADB na rede local.
- Pacote `com.ciney.app.castlite_test`, versão `1.0.47-teste-local` / 44.
- APK testado: SHA-256
  `20881DA0C1CA9AB72C605BE2DD139C1ABFB6346D55E9FE053EDEAA6133BB5767`.
- Receptor apresentado pelo app como **tv ney**, protocolo Google Cast.
- Fonte HLS de **Shrek**, já aberta pelo usuário no aplicativo.
- Observação por eventos CastLite, sessão de mídia do Android e UI nativa.
  Não houve captura da tela da TV nem medição independente de imagem/som.
- Horários abaixo são de São Paulo. A skill de dispositivos foi consultada;
  sem CLI Maestri disponível, foi usado o ADB já autorizado. Os snapshots foram
  usados para localizar controles; URLs, cookies e credenciais não integram este
  relatório. A inspeção de metadados do WebView foi somente leitura.

## Casos executados

| Caso | Evidência observada | Resultado |
| --- | --- | --- |
| Carregar a mídia | LOAD às 22:58:07,282; primeiro PLAYING às 22:58:12,703; breve buffering adicional até PLAYING às 22:58:15,654 | Reprodução iniciada segundo o receptor |
| Qualidade máxima da fonte | Manifesto anuncia uma variante `1280x720`, BANDWIDTH 1.792.000 bit/s; receptor solicita essa variante; controle mostra 1280x720 | Confirmado 720p solicitado, sem queda registrada |
| Avanço normal | Posição avançou para 32,533 s e depois 54,740 s | Confirmado no estado da sessão |
| Pausa maior que o prazo do watchdog | PAUSED às 22:59:08,728 em 54.740 ms; ainda PAUSED às 23:00:07 no mesmo ponto; nenhuma recarga registrada durante a pausa | Passou, aproximadamente 58 s |
| Retomada | PLAYING às 23:00:08,753 em 55.289 ms; leitura posterior em 77.727 ms | Passou |
| Avançar 10 s | Botão +10 levou a 89.120 ms; houve buffering breve e retorno a PLAYING | Comando funcionou; buffering deve ser contabilizado |
| Voltar 10 s durante buffering | Em 93.515 ms, botão −10 levou exatamente a 83.515 ms às 23:00:43,819; PLAYING às 23:00:43,909 | Passou no caso observado |
| Estabilidade no trecho seguinte | Após tocar novamente até aproximadamente 93,5 s, voltou a BUFFERING | Não passou para essa fonte |
| Recusa da origem | Recargas às 23:01:17,668, 23:02:04,309 e 23:02:50,851 em 93.505 ms; respostas posteriores 403 em manifesto/segmentos | Falha real da fonte observada; não é prova de internet lenta |
| Aviso ao usuário | UI capturada com “A fonte recusou o acesso ao vídeo”, orientação e botão Voltar à fonte; usuário também confirmou que viu o aviso | Aviso confirmado, com demora até a apresentação |
| Reabertura | Acionada a volta à fonte; houve seleção de mídia e retorno à página, mas depois a tela indicou zero vídeos detectados e nenhuma nova reprodução foi confirmada | Não aprovada; não se atribuiu uma causa sem nova investigação |
| Liberação da transmissão encerrada | Ao final, não foi encontrado CastingService ativo, nem os locks `CastLite:relay` / `CastLite:stream`, nem arquivos `cast-relay-*.part` no cache consultado | Limpeza observada após o encerramento; não é aprovação de todos os recursos do app |
| Crash | Nenhum erro fatal retornado na leitura de AndroidRuntime durante a verificação | Nenhum crash observado |

## O que o teste revelou

O retorno durante buffering não perdeu a posição, e a pausa foi respeitada por
mais de 45 s. A variante permaneceu em 720p. Esses resultados sustentam os
comportamentos correspondentes, mas não eliminam os problemas da fonte.

No trecho de aproximadamente 1min33s, o filme parou de avançar. Houve pedidos
pelo transporte de navegador com arquivos temporários ainda vazios e, depois,
recusas 403. As recargas não renovaram o acesso. Não foi determinado se a recusa
decorre de expiração, sessão da fonte, proteção do provedor ou outra condição.

O aviso ocorreu apenas após um período com tentativas/esperas. É necessário
investigar a integração entre a duração do fallback no WebView, o prazo do
watchdog e as gerações dos pedidos: uma tentativa lenta pode ser substituída
antes de comunicar sua recusa final. Isso é uma hipótese de investigação,
não uma causa já comprovada neste ensaio.

A reabertura precisa de um novo teste controlado com rastreamento da resolução
da fonte e correlação de tentativas, antes de afirmar que esse caminho recupera
o filme. Durante o teste houve confirmação do usuário sobre o aviso; não se
assumiu controle exclusivo do aparelho durante todas as interações.

## Limites e próximos testes necessários

- Comparar com uma fonte pública controlada para separar o transporte do app
  do comportamento específico do provedor usado neste ensaio.
- Medir tempo da primeira recusa nativa, início/fim do fallback e comunicação
  à sessão usando identificadores sem URLs ou tokens.
- Repetir a reabertura com uma sequência única de ações e confirmar o retorno
  à posição preservada. Não chamar a recarga da mesma URL de renovação da fonte.
- Validar explicitamente Parar durante reprodução ativa; neste ensaio a sessão
  já estava encerrada quando foi verificada a limpeza final.
- Testar DLNA, Roku, controle físico da TV, codecs diferentes e tela apagada.
- Não foi reduzida artificialmente a conexão nem desligado o Wi-Fi: isso também
  encerraria a conexão ADB usada para conduzir este teste.

Skills utilizadas: systematic-debugging, api-contract-testing e as orientações
de inspeção do dispositivo de maestri-portal-devices com fallback ADB.
Único arquivo permanente criado nesta tarefa: este relatório.
