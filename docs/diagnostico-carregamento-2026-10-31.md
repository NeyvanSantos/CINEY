# Diagnóstico do carregamento observado — 31/10/2026

## Conclusão desta observação

O filme ficou em buffering em **155.975 ms (2min35,975s)**. A variante solicitada
continuava em **1280x720**, BANDWIDTH declarado de 1.792.000 bit/s.

O relay deixou de entregar os próximos segmentos pelo transporte do navegador.
Depois apareceram recusas **HTTP 403**, inclusive da playlist usada nas recargas.
Mais tarde, o processo do aplicativo e seu WebView foram encerrados durante uma
limpeza registrada pelo Android. A morte do processo não explica o começo do
buffering, que aconteceu antes; ela impede continuar o relay daquela sessão.

## Evidências em ordem temporal

Horários de São Paulo; pacote `com.ciney.app.castlite_test`.

| Horário | Observação |
| --- | --- |
| 23:10:51 | Novo LOAD pelo Google Cast |
| 23:10:52 | Fonte anuncia 720p; receptor solicita 1280x720 |
| 23:11:04–05 | Reprodução confirmada pelo receptor a partir do ponto preservado, aproximadamente 93,5 s |
| 23:11:06–23:12:02 | Segmentos entregues com status 200; áudio e vídeo tiveram tempos diferentes |
| 23:12:08 | BUFFERING em 155.975 ms; houve transição breve para PLAYING sem avanço e retorno a BUFFERING |
| 23:12:33 | Sessão de mídia ainda em BUFFERING, velocidade 0; quatro arquivos temporários do transporte do navegador com zero bytes |
| 23:12:42 | Recarga do mesmo vídeo na posição 155.975 ms |
| 23:12:44 em diante | Respostas 403; recargas posteriores também recebem recusa da playlist |
| Durante a inspeção | Quatro requisições nativas pendentes, status 0 e sem resultado; seus frames estavam registrados na geração de página 2 |
| Durante a inspeção JS | Observadores ativos, geração 2, zero fetchControllers em execução nos frames inspecionados; a hipótese de observador simplesmente marcado como inativo não foi confirmada |
| 23:14:51,777 | Android registra encerramento do renderer WebView, motivo OTHER KILLS BY SYSTEM e descrição `SwipeUpClean` |
| 23:14:52,487 | Processo principal PID 25086 encerrado por sinal 9, motivo SIGNALED; não houve evidência de uma exceção Java fatal como causa desse evento |
| Após abrir novamente | Novo PID 31125; a sessão temporária anterior não foi restaurada e não foi encontrado CastingService daquela transmissão |

O nome `SwipeUpClean` é o que consta no registro do Android. Não se atribuiu a
ação a uma pessoa ou automação específica. Há outro registro mais antigo de
LOW_MEMORY, mas ele não foi usado como explicação para o encerramento atual.

## O que está comprovado e o que falta determinar

**Comprovado:** os dados necessários ao próximo trecho deixaram de chegar à TV;
o transporte do navegador acumulou pedidos sem resultado; a origem negou
requisições com 403; posteriormente a sessão perdeu o processo que a mantinha.

**Ainda não comprovado:** por que os pedidos nativos não chegaram a executar
fetch no JavaScript observado. É necessário correlacionar envio, recepção,
acknowledgment, frame/documento e geração. O navegador estava oculto; isso é uma
condição observada, não prova de que visibilidade, por si só, seja a causa.

Os registros disponíveis também não distinguem expiração de URL, sessão/cookies,
restrição do provedor ou outra política como motivo do 403. O identificador do
servidor HTTP não prova um desafio específico. Não há evidência suficiente para
afirmar que a causa foi somente a velocidade da internet ou a resolução.

## Implicação prática

Depois da morte do processo, abrir o app não recria os objetos de relay e a
fonte temporária anterior. Será preciso reabrir/resolver a fonte e iniciar uma
nova transmissão. Isso não garante que uma origem que continua negando acesso
vá aceitar a nova tentativa.

Antes de considerar resolvido, instrumentar o caminho Android → frame → fetch
com identificadores sem credenciais e resposta de recebimento; testar com o app
em primeiro plano, com a tela de controles aberta e com o app em segundo plano.
Comparar com uma fonte controlada e verificar que recargas não tornam obsoleta
a comunicação da primeira recusa antes de ela chegar ao serviço.

## Escopo desta tarefa

Skills: systematic-debugging, api-contract-testing e inspeção de dispositivo
conforme o fluxo de maestri-portal-devices, usando o ADB disponível.

Foram consultados logs, estado de mídia, arquivos temporários (somente tamanho),
metadados do WebView e campos de diagnóstico do processo de teste via depuração.
Não foram emitidos URLs de mídia, cookies ou tokens neste relatório. Nenhum código
de produção foi alterado. Encaminhamentos locais de depuração e scripts de
inspeção temporários foram removidos ao final.
