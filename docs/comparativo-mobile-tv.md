# CiNey mobile e TV: comparação e proposta de uma TV mais leve

Implementação posterior: [separação dos hosts e resultados](separacao-mobile-tv.md).
As tabelas abaixo preservam a situação encontrada antes dessa implementação.

Auditoria de 15/10/2026. Foram examinados os dois hosts, o código Flutter
compartilhado, os plugins Android registrados, os manifests, a configuração de
release e os APKs que já estavam no repositório. Esta etapa produz a comparação;
as remoções e a reorganização abaixo ainda não foram aplicadas.

A prioridade é retirar da TV as funções de **enviar vídeo para outro aparelho**
e de **ler QR com câmera**, além de reduzir trabalho contínuo da interface.
Ocultar botões não basta para excluir bibliotecas do APK.

## O que existe hoje

- `cinemax` é simultaneamente a aplicação mobile e o pacote compartilhado.
- `cinemax_tv/pubspec.yaml` depende de `cinemax` por `path: ../cinemax`.
- A entrada de TV chama `runCinemaxApp(isTv: true)`; várias diferenças são
  decididas durante a execução, dentro das mesmas telas.
- A lista de plugins Android gerada para TV contém **19 plugins**, incluindo
  `castlite_engine`, `mobile_scanner`, `flutter_local_notifications` e
  `embed_media_observer`. Um plugin registrado não significa que sua câmera ou
  seu serviço esteja ativo; significa que suas dependências continuam no build.
- O plugin CastLite recusa operações em Android TV, mas permanece como
  dependência Android, com Google Cast, DLNA/jUPnP, Jetty, atividades e serviço.
- O host TV configura Android 8/API 26 como mínimo e desativa tanto
  `isMinifyEnabled` quanto `isShrinkResources` no release.

Evidências: [dependências mobile](../cinemax/pubspec.yaml),
[dependências TV](../cinemax_tv/pubspec.yaml),
[entrada TV](../cinemax_tv/lib/main.dart),
[plugin CastLite](../cinemax/packages/castlite_engine/android/src/main/kotlin/com/ciney/castlite/CastLitePlugin.kt),
[dependências nativas do motor](../cinemax/packages/castlite_engine/android/build.gradle),
[Gradle TV](../cinemax_tv/android/app/build.gradle.kts).
Os arquivos gerados `.flutter-plugins-dependencies` e `GeneratedPluginRegistrant.java`
foram consultados como evidência, não devem ser editados manualmente.

## Comparação das funções

| Recurso | Mobile | Proposta para TV | Situação encontrada / efeito |
| --- | --- | --- | --- |
| Transmitir para outra TV | Manter CastLite e seleção de dispositivos. | Remover botão, diálogo de link e motor de envio do pacote TV. | Nos detalhes, a condição `!widget.isTv || castSource != null` ainda exibe **Transmitir** na TV. Nesse caso abre um diálogo para copiar link. |
| Transmitir episódio / pelo player | Manter. | Não oferecer. | Botão por episódio e botões do player já usam `!widget.isTv`; o problema restante é o botão geral e a dependência nativa. |
| Receber reprodução enviada pelo celular | O celular envia a solicitação. | Manter o receptor CiNey quando esse recurso for usado. | `TvCastListener` recebe comandos via Realtime e abre o player da própria TV. Não depende do SDK Google Cast/DLNA do CastLite. |
| Ler QR pela câmera | Manter no celular para conectar a TV. | Excluir scanner, tela de leitura, CameraX, ML Kit e permissão de câmera. | O botão do scanner fica escondido na TV, mas a rota `/tv-pair-scan` e o plugin Android continuam compartilhados. |
| Exibir QR para entrar na conta | Celular lê o QR. | Manter. | `TvPairingScreen` usa `qr_flutter`; exibir o QR não exige `mobile_scanner` nem câmera na TV. |
| Compartilhar e copiar links | Avaliar o recurso no mobile. | Remover das ações normais de conteúdo da TV. | O botão Compartilhar dos detalhes tem `onPressed: () {}`: aparece sem realizar uma ação. Copiar link da fonte também não ajuda a reprodução na TV. |
| Rotação de tela | Manter preferência mobile. | Não mostrar configuração de rotação mobile. | A preferência já fica escondida com `!AppEnvironment.isTv`. Preservar esse comportamento. |
| Navegação | Toque e barra inferior. | Manter navegação lateral, foco, setas, OK e Voltar. | Já existe navegação específica para TV. A mudança deve preservar a operação pelo controle remoto. |
| Player e fontes | Manter os caminhos necessários ao mobile. | Manter reprodução de embeds e reprodução nativa de links diretos. | A TV utiliza `TvSourcePolicy`, `TvEmbedPlayer` e o player nativo. Remover WebView ou `video_player` quebraria fontes atuais. |
| Observador de mídia do mobile | Manter onde acompanha frames do WebView mobile. | Candidato a sair do pacote TV após separar os players. | A classificação TV retorna para `TvEmbedPlayer` ou para o player nativo antes de entrar no WebView mobile que instala `EmbedMediaObserver`. Não confundir com os scripts usados pelo próprio player TV. |
| Catálogo, busca, episódios e coleções | Manter. | Manter. | São funções de navegação e consumo do conteúdo, não recursos dispensáveis do celular. |
| Conta, favoritos e Continuar Assistindo | Manter. | Manter. | A conta controla a entrada; histórico e favoritos são úteis na TV e precisam continuar sincronizados. |
| Retomar, próximo episódio, áudio e legendas | Manter. | Manter com controles acessíveis por D-pad. | São partes essenciais da reprodução. Não reduzir a qualidade de vídeo apenas para diminuir o tamanho do APK. |
| Extensões e repositórios | Manter gerenciamento completo. | Manter as fontes instaladas e sua atualização; tornar edição de URLs/repos uma opção avançada. | O motor de fontes continua necessário. Simplificar a tela não autoriza apagar os provedores que alimentam o catálogo. |
| Avisos do aplicativo | Notificação Android pode continuar. | Preferir aviso dentro do app; avaliar excluir o plugin de notificação do sistema. | Os avisos e sua assinatura Realtime são iniciados na base compartilhada. Preservar a entrega de mensagens caso o modo de exibição seja trocado. |
| Logs e diagnóstico | Manter para suporte. | Resumo de erros e diagnóstico avançado, sem painel detalhado na navegação principal. | O logger já limita o histórico a 500 entradas. Não foi identificado um histórico ilimitado. |
| Atualizar o próprio app | Manter. | Manter o canal TV, o instalador, a assinatura e a verificação SHA-256. | `AppUpdater` escolhe o canal TV; o APK é baixado para diretório temporário do app. Essas funções não são download de filmes. |
| Download de filmes | Não foi encontrado módulo ativo nesta revisão. | Não adicionar por padrão à TV. | Há comentário antigo de “Download” nos detalhes e referência documental antiga, mas não um módulo ativo de downloads no diretório de funcionalidades. |

Fontes principais: [detalhes](../cinemax/lib/features/details/presentation/details_screen.dart)
(linhas 198–245, 397–400, 536–563 e 794–810),
[player](../cinemax/lib/features/player/presentation/player_screen.dart)
(linhas 807–831, 967 e 1980/2236),
[rotas](../cinemax/lib/core/routes/app_router.dart),
[receptor TV](../cinemax/lib/features/player/presentation/tv_cast_listener.dart),
[pareamento por QR](../cinemax/lib/features/auth/presentation/tv_pairing_screen.dart),
[scanner](../cinemax/lib/features/auth/presentation/tv_pairing_scanner_screen.dart).
Os botões que pertencem à página de um provedor dentro do WebView não são
controles Flutter do CiNey; a tabela se refere às ações do próprio aplicativo.

## O que pesa na interface e no armazenamento

| Ponto | Evidência atual | Ajuste proposto para TV |
| --- | --- | --- |
| Rolagem automática de lançamentos | `home_screen.dart:669` cria um `Timer.periodic` a cada **24 ms**, sem condição de plataforma. | Desligar rolagem automática na TV; mover as listas pelo foco. Evitar atividade periódica quando a Home estiver coberta pelo player ou em segundo plano. |
| Desfoque de cartões | `GlassCard` aplica `BackdropFilter` com blur padrão 20. | Usar superfície sólida na TV e manter realce simples de foco. Medir frames antes/depois. |
| Splash e animações | Splash espera 1.500 ms, mais uma espera de 300 ms, e aplica efeitos com repetição. | Inicialização curta na TV, sem espera artificial nem efeitos contínuos. Preservar o carregamento e os erros necessários. |
| Shimmer de carregamento | Posters usam `ShimmerLoading`. | Preferir placeholder estático no modo de TV leve e reduzir elementos animados simultâneos. |
| Imagens de catálogo | TV já solicita poster `w342` e backdrop `w780`; `GradientPoster` já limita o decode ao tamanho exibido. | Preservar os limites existentes e acrescentar orçamento de cache em memória/disco, medido no aparelho. Não voltar a imagens maiores do mobile. |
| “Limpar cache” | `profile_screen.dart:236–247` só registra log e mostra a mensagem de sucesso. | Executar limpeza real dos caches de imagem/arquivos e informar o resultado; preservar sessão e histórico. É uma correção útil às duas versões, especialmente à TV. |
| Logos duplicados | O APK TV contém duas entradas de `logo.png`, uma em `assets/icons` e outra em `assets/images`, com 436.654 bytes cada. | Consolidar o recurso após ajustar suas referências. Ganho menor que remover scanner e arquiteturas extras. |

Tamanho do APK, armazenamento após instalar, RAM, uso da GPU e tráfego de rede
são medidas diferentes. Retirar uma biblioteca do APK não prova, sozinho,
melhora de fluidez. As recomendações de memória para TVs de pouca RAM estão
no [guia Android TV](https://developer.android.com/training/tv/playback/memory).

## Medição dos APKs já existentes

Os números abaixo vieram da leitura das entradas ZIP, usando `CompressedLength`.
Não foi compilado outro APK para esta comparação.

| Arquivo local | Bytes do arquivo | MiB |
| --- | ---: | ---: |
| `releases/mobile/CiNey-v1.0.38.apk` | 87.042.304 | 83,01 |
| `releases/tv/CiNey-v1.0.39-TV.apk` | 87.090.783 | 83,06 |

São versões distintas, salvas em 12/10/2026, anteriores à integração CastLite
em análise. Servem para identificar componentes do APK TV existente; não são
uma medição de antes/depois da integração atual. O APK debug instalado no
BlueStacks também não serve de comparação com esses APKs release.
[A documentação Flutter explica essa diferença](https://docs.flutter.dev/perf/app-size).

No APK TV examinado:

| Componente | Bytes dentro do ZIP |
| --- | ---: |
| Bibliotecas nativas ARM64 | 25.419.592 |
| Bibliotecas nativas ARMv7 | 21.498.304 |
| Bibliotecas nativas x86_64 | 27.827.272 |
| DEX, compactado | 9.267.354 |
| `libbarhopper_v3.so`, somadas as três arquiteturas | 14.100.440 |
| Modelos de leitura de código de barras | 880.888 |

Bibliotecas de barcode e modelos somam **14.981.328 bytes / 14,29 MiB** dentro
do APK universal. Esse é um alvo concreto de remoção na TV. O ganho final
precisa ser medido após a exclusão do plugin e do código que o referencia.

Em um aparelho ARM64, as entradas ARMv7 e x86_64 representam **47,04 MiB**
do arquivo universal que não correspondem à arquitetura usada naquele aparelho.
A proposta é fornecer APK por arquitetura. TVs com sistema Android de 32 bits
precisam continuar recebendo ARMv7, mesmo quando o processador físico suporta
64 bits. x86_64 pode permanecer como artefato de teste e deve ser mantido na
distribuição se houver aparelhos compatíveis a atender.

**Não somar diretamente os 14,29 MiB do scanner aos 47,04 MiB das arquiteturas**:
há sobreposição, pois as bibliotecas do scanner estão dentro dessas mesmas
pastas. Também não há ainda um número isolado para o CastLite no APK TV atual.

O atualizador e o workflow procuram o nome único `CiNey-v<versão>-TV.apk`.
Separar os APKs exige também escolher o arquivo correspondente às ABIs
suportadas pelo Android do aparelho, com compatibilidade para os nomes antigos.
Mudar só a compilação deixaria o instalador sem encontrar o arquivo correto.

## Separação necessária na arquitetura

Proposta de dependências:

```text
cinemax (host mobile) ──┬── núcleo compartilhado
                       ├── castlite_engine
                       └── mobile_scanner

cinemax_tv (host TV) ────── núcleo compartilhado
                           + player TV e receptor de comandos
```

O núcleo compartilhado deve conter catálogo, modelos, fontes, conta, favoritos,
histórico e os serviços realmente comuns. Os hosts fornecem as implementações
de envio, scanner e avisos que utilizam. Telas e rotas exclusivas do mobile
ficam fora da composição da TV. O player pode continuar compartilhando seus
contratos e histórico sem incluir a tela e o motor de envio do CastLite.

Só usar `if (!isTv)` ou um sinalizador Dart não remove automaticamente o plugin
Android transitivo declarado no `pubspec` compartilhado. Não editar o registro
gerado nem excluir JARs manualmente para simular essa separação.

Depois da separação, revisar o manifesto final: câmera, leitura de mídia e
armazenamento legado são candidatos a sair; multicast, atividades privadas e
serviço de envio devem desaparecer com o motor CastLite. Não remover
indiscriminadamente rede, instalador de atualizações ou `WAKE_LOCK`, que podem
ser necessários a recursos mantidos. O Android mínimo continua 8+ conforme a
decisão existente; retirar Jetty permite reavaliar compatibilidade depois,
mas isso não implica baixar o mínimo automaticamente.

Chewie é candidato a uma revisão posterior porque o player já usa controles
próprios (`showControls: false`). Não é o primeiro corte: ainda envolve o caminho
nativo da TV e exige validar tela cheia, proporção, reprodução e descarte.
Da mesma forma, JNI e `path_provider` não devem ser removidos só por aparecerem
no registro: também sustentam armazenamento e atualização.

## Ordem recomendada de execução

1. **Remover ações inúteis da TV:** Transmitir nos detalhes, copiar link de
   transmissão, Compartilhar sem ação e acesso à rota do scanner. Manter foco,
   Assistir, favoritos e escolha de episódios/servidores.
2. **Separar dependências:** retirar CastLite e scanner da árvore de dependências
   do host TV, preservando o motor e os recursos do mobile. Conferir o manifesto
   mesclado e o registro de plugins da TV.
3. **Reduzir trabalho contínuo:** carrosséis estáticos, efeitos mais simples,
   splash curto, cache real e orçamento de imagens na TV.
4. **Otimizar a compilação release:** avaliar `isMinifyEnabled = true` e
   `isShrinkResources = true`, com regras necessárias aos plugins e testes
   do player. O projeto usa AGP 8.11.1; não presumir recursos que exigem AGP
   mais recente. [Referência Android sobre R8](https://developer.android.com/topic/performance/app-optimization/enable-app-optimization).
5. **Separar APKs por arquitetura:** ajustar seleção do atualizador, nomes de
   artefatos e verificações de assinatura/hash. Usar análise de tamanho release
   por arquitetura e comparar a mesma revisão/configuração. Avaliar
   `--split-debug-info` guardando os símbolos para diagnóstico.
6. **Validar na TV física:** início, login por QR, busca, navegação por controle,
   MP4/HLS e embeds dos provedores atuais, troca de servidor, áudio/legendas,
   retomada, próximo episódio, receber comando do celular e atualização.
   Medir memória, frames, cache e retorno do player para a Home.

Não há meta de tamanho final ou percentual de ganho comprovado antes dessa
compilação e das medições. O plano prioriza os componentes medidos, sem trocar
economia de espaço por quebra de reprodução. Publicação não faz parte desta
auditoria e continua sem autorização para esta integração.
