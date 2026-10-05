# CiNey TV

Variante Android TV independente, com `applicationId` `com.ciney.tv`. O app
mobile permanece em `../cinemax` e pode ser instalado junto com esta variante.

## Executar na TV

Conecte uma Android TV ou inicie um emulador de TV e rode:

```powershell
flutter pub get
flutter run
```

O launcher usa Leanback e touchscreen opcional. A navegação lateral e os cards
suportam foco do controle remoto; o player nativo responde às teclas de mídia.
O banner fica em `android/app/src/main/res/drawable/tv_banner.xml`.

## Validar

```powershell
flutter analyze
flutter test
```

Os testes `stream_resolver` e `plugin_manager` copiados do app base esperam duas
fontes, enquanto a implementação atual retorna quatro; essa divergência não
foi alterada nesta variante.

## Release

Esta pasta não inclui automação de publicação. Configure uma keystore própria e
um fluxo de release separado para o `applicationId` `com.ciney.tv`; não use os
scripts de publicação do app mobile.

---

## Documentação herdada do CiNey

CineMax - Filmes e Series com Sistema de Plugins

## Console de logs

Abra **Perfil → Console de Logs em Tempo Real** para acompanhar buscas,
resolução de fontes, carregamento do player, troca de servidores e erros.
O console oferece filtros por nível, pesquisa por mensagem ou tag e rolagem
automática. **Copiar Tudo** copia as entradas visíveis (respeitando os filtros);
**Limpar todos os logs** esvazia o histórico imediatamente.

Os últimos 500 registros ficam em memória durante a sessão. Ao encerrar o
processo do aplicativo, o histórico é perdido; copie os registros antes de sair
quando precisar compartilhar um diagnóstico. Erros Flutter e erros assíncronos
não tratados incluem a pilha de execução quando disponível.

Validação automatizada: `flutter test --no-pub`.

## Reprodução incorporada

Fontes incorporadas usam JavaScript e os controles do próprio fornecedor,
sem sobreposição dos controles de reprodução do aplicativo. Use o botão/gesto
Voltar do Android para sair.

**EmbedMovies** é o único servidor de reprodução do aplicativo. Os conteúdos
TMDB e os IDs internos mapeados usam seus respectivos IDs; outros títulos dos
catálogos precisam ser identificados no TMDB antes de gerar o endereço.
A [documentação do fornecedor](https://embedmovies.org/) utiliza
`https://myembed.biz/filme/ID` para filmes e
`https://myembed.biz/serie/ID/TEMPORADA/EPISODIO` para episódios. Sem um episódio
escolhido, o endereço `https://myembed.biz/serie/ID` abre a lista da série.
O app incorpora esse endereço em um iframe, como exigido pelo fornecedor,
em vez de navegar diretamente para a página. Os plugins continuam fornecendo
os catálogos, mas suas fontes de vídeo alternativas não são utilizadas.

Gerar o endereço e carregar a página não confirmam a disponibilidade ou a
reprodução do vídeo. A qualidade e o acervo dependem do EmbedMovies. A integração
registra mídia pronta e reprodução quando consegue observar o vídeo. Iframes
de outro domínio podem impedir essa observação; nesse caso, o app registra
a limitação e preserva a reprodução e os controles do fornecedor. Não há troca
automática para outro fornecedor.

Teste do script de integração: `node --test test/embed_bridge_test.cjs`.

## Transmitir para Chromecast / Google TV

A opção **Transmitir** abre um único fluxo de espelhamento pelo Google Home,
adequado ao player incorporado do EmbedMovies. O endereço HTML do fornecedor
não é enviado ao receptor Google Cast como se fosse um arquivo de vídeo.

Use a mesma rede Wi-Fi no celular e na TV. No Google Home, abra o bloco da TV,
selecione **Transmitir tela** (ou **Transmitir um app**, quando disponível) e
confirme no Android. Depois volte ao Cinemax e toque em **Abrir filme**.
O espelhamento é encerrado pelo Google Home; abrir esse aplicativo não confirma
que a TV está conectada. O celular deve permanecer desbloqueado durante o uso.

Se o Google Home não estiver instalado, o diálogo oferece um botão para abrir
sua página oficial no Google Play. [Instruções do Google](https://support.google.com/googlecast/answer/6059461?hl=pt-BR).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
