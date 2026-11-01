# Plano de correção da transmissão CiNey / CastLite

Data: 31/10/2026. Estado: desenho aprovado pelo usuário ("Pode aplicar");
correções implementadas e verificadas em testes. Ensaios físicos por protocolo
continuam necessários. Ver [registro da aplicação](correcoes-transmissao-2026-10-31.md).

Base: [auditoria da transmissão](revisao-transmissao-2026-10-31.md).
Skill aplicada nesta etapa: brainstorming.

## 1. Entendimento confirmado pelo usuário

- Preservar o fluxo filme → seleção da TV → reprodução e controle pelo celular.
- Buscar a maior qualidade da fonte compatível com o receptor, sem modo econômico.
- Conservar título, episódio, áudio, legendas, posição e integração com WebView.
- Corrigir falhas de acesso, entrega de bytes e recuperação com testes específicos.
- Preservar Google Cast, DLNA e Roku e a separação dos hosts mobile / Android TV.
- Trabalhar em etapas reversíveis, respeitando as alterações existentes no checkout.

O usuário confirmou esse entendimento antes da preparação desta proposta.

## 2. Premissas e limites

Uma transmissão ativa por sessão continua sendo o modelo. O relay permanece no
celular, sem servidor novo, serviço pago, transcodificação ou dependência nova
planejada. Não baixar o filme inteiro para iniciar a reprodução. Memória, disco,
requisições pendentes e vida das rotas precisam ter limites verificáveis.

Cookies e tokens permanecem em memória no escopo da origem correspondente.
Logs e eventos de diagnóstico carregam categorias, estados, tempos, contadores
e identificadores de tentativa; nunca URLs assinadas ou credenciais.

Qualidade máxima não significa imagem criada acima da fonte nem reprodução
garantida em rede insuficiente. A prioridade de qualidade é mantida; dificuldade
de rede não deve disparar queda silenciosa para 360p. Uma troca de servidor
precisa preservar o contexto e ficar visível ao usuário.

Manutenção: usar os componentes e runners existentes; cada etapa deve poder ser
revisada e revertida isoladamente. Não modificar banco, autenticação da conta,
catálogo ou player da variante TV para resolver defeitos exclusivos do CastLite.
Mudança compartilhada só entra se uma dependência concreta for demonstrada.

## 3. Abordagens consideradas

| Abordagem | Vantagens | Custo e risco | Recomendação |
| --- | --- | --- | --- |
| A. Correções graduais dentro dos componentes atuais, começando pelas falhas reproduzidas e fronteiras de segurança | Menor superfície de alteração; comparação com a versão atual; entregas pequenas | Exige contratos claros entre relay, sessão e protocolo para evitar remendos dispersos | Recomendada |
| B. Unificar primeiro toda a coordenação de sessão e transporte, depois migrar os três protocolos | Pode reduzir duplicação de estado no longo prazo | Refatoração maior antes de corrigir o defeito observado; maior esforço de regressão e rollback | Reservada para o caso de a abordagem A revelar acoplamento que impeça correções locais |

O desenho abaixo segue A. Extrações locais de lógica pura são aceitáveis quando
necessárias para testes; uma reescrita geral não faz parte da proposta.

## 4. Responsabilidades preservadas

- Flutter/bridge: contexto do filme/episódio e comandos; eventos públicos sem segredos.
- Navegador/observador: obter mídia e manter a sessão legítima da fonte.
- Relay: política de cabeçalhos, bytes, intervalos HTTP e reescrita de HLS.
- Serviço de transmissão: intenção do usuário, geração atual e recuperação limitada.
- Adaptadores: comandos e estado real de cada protocolo, declarando suas limitações.

Separar três fatos nos estados e mensagens: dispositivo conectado, carregamento
aceito pelo protocolo e reprodução confirmada. Não marcar sucesso de reprodução
somente porque um comando LOAD, Play ou launch retornou sucesso.

Cada tentativa deve ter uma geração. Respostas de downloads, resolução de fonte
ou comandos antigos não podem atualizar a sessão nova, alterar sua posição nem
encerrar seus recursos. Uma falha de segmento isolada não deve, sozinha,
substituir uma reprodução que continua avançando normalmente.

## 5. Etapa 0 — Fixar referência e transformar achados em regressões

Registrar o estado do checkout sem desfazer trabalho existente. Usar mudanças
isoladas por etapa e manter uma compilação de referência identificada por hash.

Adicionar à suíte permanente os três cenários já reproduzidos: continuação HTTP
além do intervalo pedido; seek para 80 s recuperando em 11 s; seek de volta do
fim que desativa recuperação. Cada teste deve falhar no comportamento atual e
passar após a correção correspondente.

Acrescentar fixtures de cabeçalhos entre duas origens, 401/403 persistente,
playlist parcial, comandos antigos e pausa/retomada externa. Todas sintéticas,
usando servidores locais e os runners já disponíveis.

Saída: referência reproduzível e testes que demonstram os defeitos; não aumentar
timeouts ou alterar fixtures para esconder falhas.

## 6. Etapa 1 — Integridade e segurança do relay

Arquivos principais: `RelayHttpSource.kt`, `LocalMediaProxy.kt`, testes HTTP/HLS.

- Validar início, fim, total e tamanho do intervalo retornado; limitar os bytes
  entregues ao corpo prometido e preservar validadores de conteúdo.
- Tratar comprimento desconhecido com segurança: não inventar uma continuação
  que possa duplicar ou misturar bytes.
- Associar Authorization/Cookie explícitos à origem correta. Considerar esquema,
  host e porta, além de reavaliar o escopo em redirecionamentos.
- Consultar cookies para o destino efetivo. Integrações que exigirem credenciais
  em CDN diferente precisarão de política explícita; não confiar só no domínio
  parecido, no conteúdo do manifesto ou em uma comparação por substring.
- Conservar os cabeçalhos públicos necessários, como Referer, conforme contrato
  da fonte. Testar origem principal e CDN legítimo para não quebrar integrações.

Aceitação: bytes exatamente iguais nas retomadas válidas; resposta incompatível
rejeitada; nenhuma credencial sintética chega a uma origem não autorizada;
fontes que usam CDN e cookies por destino continuam funcionando.

## 7. Etapa 2 — Recuperação coerente com seek, pausa e falhas

Arquivos principais: `PlaybackRecovery.kt`, `CastingService.kt`, controles e plugin.

Comunicar todo seek por um caminho consistente: destino pendente, posição
confirmada e último progresso são dados diferentes. Limpar o seek pendente ao
confirmar, falhar ou trocar de geração. Não interpretar buffering próximo ao fim
como término confirmado.

Conciliar pausa solicitada com o estado informado pela TV. Retomar no controle
físico deve reativar o monitoramento, sem desfazer pausas legítimas. Proteger
contra callbacks atrasados de pause/play e comandos que falharam.

Propagar erros do relay por categorias: acesso negado, transporte temporário,
resposta inválida, sessão encerrada e incompatibilidade quando confirmada.
Manter inicialmente os limites existentes de recarga/espera; qualquer ajuste
posterior precisa de medição e teste.

Para 401/403 persistente, limitar a tentativa de recuperar a sessão legítima da
fonte. Usar uma nova resolução apenas quando o fluxo existente permitir; caso
contrário, oferecer reabertura ou troca de servidor, preservando o ponto e o
episódio. Não prometer renovar uma URL direta quando não existe resolvedor para
ela. Não contornar bloqueios, DRM ou desafios do provedor.

Aceitação: os três testes reproduzidos passam; recargas têm orçamento;
pausa, fim e stop não reiniciam o filme; 403 persistente termina com ação clara;
eventos de tentativas anteriores não contaminam a transmissão atual.

## 8. Etapa 3 — Unificar o comportamento HTTP e navegador

Arquivos principais: relay, `FrameMediaTransport.kt`, `RelaySpool.kt`, observador JS.

Definir a mesma política para manifestos completos nos dois transportes.
Playlists HLS não podem sair parciais e sem reescrita. Preservar Range nos
segmentos e arquivos que realmente dependem dele; manter áudio, legendas,
chaves, inicialização de mídia e URLs assinadas.

Tratar MP4 protegido somente com suporte verificável a intervalos, cancelamento,
comprimento e integridade. Não habilitar fetch do arquivo inteiro nem aumentar
o limite de 128 MiB para mascarar a limitação. Se o provedor não permitir a
leitura necessária, informar a limitação e oferecer outra fonte.

Verificar encerramento após timeout/cancelamento, liberação dos slots, arquivos
temporários e requisições antigas. Medir tempo até os primeiros bytes e tempo
total, separadamente. Mudança de cache, pooling ou paralelismo só deve entrar
se uma medição demonstrar benefício e não violar tokens, Range ou cancelamento.

Aceitação: mesmos bytes e metadados nos dois caminhos; início por streaming;
cancelamento libera recursos; arquivos grandes não exigem acumular tudo em RAM
ou disco; manifestos não expõem rotas inválidas à TV.

## 9. Etapa 4 — Maior qualidade compatível, sem modo econômico

Arquivos principais: `HlsPlaylist.kt`, contrato de capacidades e adaptadores necessários.

Investigar primeiro quais informações o receptor/SDK realmente fornece. Registrar
suporte conhecido, incompatibilidade confirmada e capacidade desconhecida. Não
deduzir suporte a 4K/HEVC somente pelo nome da TV ou pela conexão estabelecida.

Quando houver evidência confiável de capacidades, selecionar a maior resolução
compatível da fonte; preservar alternativas de codec/áudio necessárias nessa
resolução. Testar variantes de resoluções e codecs diferentes e empates de
resolução com bitrates diferentes, para não tratar resolução como a única medida
de qualidade.

Quando capacidades forem desconhecidas, não inventar uma garantia de suporte.
Manter a preferência máxima disponível e informar incompatibilidade quando
confirmada. Um erro genérico ou 403 não autoriza classificar codec como inválido.
A estratégia para receptores sem informação suficiente precisa ser validada
antes de implementar fallback automático de compatibilidade.

Dificuldade de rede não provoca redução silenciosa. Mostrar qualidade solicitada
pela TV e estado de buffering sem afirmar que uma resolução foi decodificada
quando o protocolo só informa qual variante foi pedida.

Aceitação: na fonte 360p/720p já observada, continuar solicitando 720p; fontes com
4K incompatível e alternativa compatível usam a melhor opção comprovada; áudio
e legendas permanecem corretos. Nenhum item ou preferência de economia retorna.

## 10. Etapa 5 — Estado real e ciclo de vida por protocolo

DLNA: consultar/assinar AVTransport quando suportado, reconciliando posição,
pausa, buffering, término e falhas de comunicação. Declarar capacidade ausente
quando a TV não fornecer estado suficiente, em vez de simular reprodução.

Tornar descoberta DLNA idempotente, com estados explícitos de inicialização e
cancelamento. Uma inicialização obsoleta deve fechar o serviço que acabou de
criar. Encerrar polling, descoberta, sockets e locks ao parar ou concluir.

Google Cast: testar restauração da sessão, troca de cliente do SDK, controle
externo, saída do navegador e reconexão, preservando geração e intenção do usuário.

Roku: verificar estado real após launch/Play e falhas de comandos. Conservar e
documentar a limitação de seek aproximado do protocolo atual; não prometer
retomada exata onde ela não existe.

Aceitação: repetir buscar/conectar/parar não acumula recursos; terminar/pausar
na TV reflete no app; parar permanece definitivo; fechar a tela não interrompe
uma sessão ativa legítima. Verificação física separada por protocolo.

## 11. Matriz de validação e critérios de entrega

| Área | Casos necessários |
| --- | --- |
| Fonte | MP4 público, HLS master, HLS sem variantes, sessão protegida, URL indisponível |
| Rede | Fluxo normal, resposta truncada, leitura lenta, queda breve, 403 persistente |
| Controles | Pausar/retomar no app e na TV, seek durante buffering, voltar do fim, parar durante recarga |
| Contexto | Episódio diferente, áudio selecionado, legendas, troca de servidor, posição preservada |
| Qualidade | 360p/720p, codecs alternativos, 4K sem suporte conhecido, metadados incompletos |
| Recursos | Tela apagada, app em segundo plano, fechar navegador, encerrar sessão, buscar várias vezes |

Executar os testes JVM/JS do CastLite e os testes Flutter pertinentes a cada
mudança; `flutter analyze --no-pub` e lint Android antes de cada entrega.
Não declarar aprovado um protocolo físico com base apenas em fixtures.

Comparar a mesma fonte, receptor e condição de rede com a referência. Registrar
tempo até reprodução, pausas de buffering por intervalo observado, posições,
variante solicitada e recursos antes/depois de parar. Não estabelecer um prazo
universal de início porque a fonte e a rede são externas. Qualquer regressão
reproduzível exige investigação antes da entrega seguinte.

## 12. Entrega e reversão

Entregar uma etapa por conjunto de mudanças, com testes e limitações descritos.
Separar correções de bytes/cabeçalhos, recuperação, fontes e protocolos para
permitir reversão localizada. Não usar reset do checkout ou remover trabalho
anterior do usuário como estratégia de rollback.

Gerar APK de teste somente com autorização aplicável e instalar no pacote de
teste para comparar sem substituir a instalação principal. Preservar uma cópia
identificada da referência. Sem push, tags ou publicação pública neste plano.

Antes de integrar uma etapa, confirmar que o menu de economia continua ausente
e que o fluxo de transmissão e os contextos existentes foram preservados.
Documentar aparelhos/protocolos indisponíveis como pendências, sem alegar teste
físico realizado.

## 13. Registro de decisões

| Decisão | Estado | Motivo / alternativa |
| --- | --- | --- |
| Preservar o fluxo atual e os três protocolos | Confirmado pelo usuário | Manter a ideia da transmissão |
| Sem modo econômico; máxima qualidade compatível | Confirmado pelo usuário | Evitar a queda de qualidade observada |
| Correção gradual na arquitetura atual | Aprovada | Menor risco que unificação estrutural prévia |
| Tratar 403 como acesso negado, sem presumir internet lenta | Aplicada | Evidência real; origem exata do bloqueio ainda desconhecida |
| Reabrir/resolver fonte com contexto e tentativas limitadas | Aplicada pela ação explícita Voltar à fonte | Recarregar a mesma URL não renova acesso |
| Investigar capacidades antes de prometer fallback por codec | Mantida a condição de suporte desconhecido | Não há contrato confiável de codecs/resoluções nos adaptadores atuais; não inventar suporte |
| Critérios e matriz de teste por etapa | Testes automatizados executados; ensaios físicos pendentes | Suíte anterior não cobria os defeitos reproduzidos |

## 14. Validação pendente

O usuário aprovou a aplicação. A disponibilidade de capacidades e de renovação
automática de uma fonte depende do receptor e da integração. Nesta entrega,
preserva-se a qualidade máxima declarada quando o suporte é desconhecido e a
reabertura é uma ação explícita do usuário. Não se afirma detecção universal de
codecs da TV nem renovação automática de qualquer link direto. A matriz física
permanece pendente e os resultados devem ser registrados por aparelho/protocolo.
