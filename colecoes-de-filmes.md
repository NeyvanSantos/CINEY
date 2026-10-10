# Plano: Coleções de filmes

## Visão geral

Agrupar filmes que pertencem à mesma franquia em uma coleção navegável, como **Velozes e Furiosos**, **Harry Potter** e **Shrek**. A coleção deve exibir os filmes em sequência e permitir abrir os detalhes de cada título para iniciar sua reprodução normalmente.

A associação será obtida dos metadados do TMDB (`belongs_to_collection` no detalhe do filme e `/collection/{id}` para os itens). Não será criada uma lista manual de franquias nesta primeira versão.

## Tipo de projeto

**MOBILE**, em Flutter. A implementação ficará na base compartilhada `cinemax/`, portanto a experiência também deverá funcionar no host Android TV `cinemax_tv/`.

## Escopo e decisões

- Incluir somente filmes (`ContentType.movie`). Séries, temporadas e episódios não fazem parte desta funcionalidade.
- A coleção será descoberta pela ficha de um filme associado no TMDB e também pela seção **Coleções** em Início, visível nos filtros “Todos” e “Filmes”.
- Como a API TMDB não oferece um índice global de coleções, a seção inicial usará uma lista curada de IDs de coleções TMDB, expansível posteriormente. Os dados e filmes de cada coleção continuam vindo da API.
- A página da coleção mostrará nome e filmes retornados pelo TMDB; itens sem associação a uma coleção não exibirão a seção.
- **Ordem aplicada nesta versão:** data de lançamento crescente, com itens sem data ao final e ID como desempate. Isso é uma ordem de lançamento, não necessariamente a cronologia interna da história.
- A Home carrega metadados das cinco coleções em destaque; “Ver todas” carrega o catálogo completo e os filmes de cada coleção são carregados ao abrir a coleção.
- Não são necessárias alterações no Supabase, favoritos ou histórico.

## Critérios de sucesso

1. Início exibe a prateleira “Coleções” nos filtros “Todos” e “Filmes”, com acesso à lista inicial de coleções curadas.
2. Um filme TMDB associado a uma coleção exibe essa associação na tela de detalhes.
3. Ao abrir uma coleção, a tela lista seus filmes na ordem definida, com pôster, título e ano quando disponíveis.
4. Selecionar um filme abre os detalhes normais desse filme; a reprodução continua usando os IDs TMDB já aceitos pelo motor atual.
5. Coleção ausente, lista vazia, carregamento e erro de rede têm estados tratados; uma falha não impede consultar os detalhes do filme original.
6. A navegação funciona por toque no celular e por foco/controle remoto na TV.
7. Testes cobrem mapeamento, ordenação, ausência de associação e falha da consulta; `flutter analyze` e a suíte Flutter passam.

## Stack

- Flutter e Dart existentes.
- `Dio` e `TmdbService` para consultas à API TMDB, mantendo o idioma `pt-BR`.
- Riverpod para integração com os serviços/estado, seguindo os padrões já usados no app.
- GoRouter para a rota da página da coleção.
- Testes Flutter com `Dio` injetável/mockado; sem depender de rede real.

## Estrutura prevista

```text
cinemax/lib/
├── features/collections/
│   ├── presentation/movie_collections_screen.dart
│   └── presentation/movie_collection_screen.dart
├── features/home/presentation/home_screen.dart
├── features/details/presentation/details_screen.dart
├── core/routes/app_router.dart
└── plugin_engine/
    ├── models/content_item.dart
    ├── models/movie_collection.dart
    └── runtime/tmdb_service.dart

cinemax/test/
└── movie_collections_test.dart
```

A estrutura é uma proposta: durante a implementação, reutilizar a organização atual do módulo de detalhes e evitar duplicar acesso HTTP se for mais simples estender `TmdbService`.

## Tarefas

### T1 — Fechar contrato e regra de ordenação

- **Agente recomendado:** `mobile-developer`
- **Skill recomendada:** `brainstorming`
- **Prioridade:** P0
- **Dependências:** nenhuma
- **Entrada:** metadados `/movie/{id}`, exemplos Velozes e Furiosos, Harry Potter e Shrek.
- **Saída:** ordem de lançamento aplicada; campos necessários para metadados/lista de coleção.
- **Verificação:** data ausente vai ao final; ID desempata; consulta real do TMDB foi instável durante a validação.
- **Recuperação:** manter ordenação por lançamento como fallback previsível se não houver decisão sobre ordem narrativa.

### T2 — Modelar e consultar coleção

- **Agente recomendado:** `mobile-developer`
- **Skill recomendada:** `clean-code`
- **Prioridade:** P1
- **Dependências:** T1
- **Entrada:** resposta de detalhe de filme e resposta `/collection/{id}`.
- **Saída:** metadados de coleção ligados ao detalhe do filme, modelo da coleção e consulta que converte as partes do TMDB em itens de filme na ordem definida.
- **Verificação:** testes com respostas simuladas validam IDs, nome, pôsteres, datas, ordenação, campos ausentes e erro de rede.
- **Recuperação:** retirar os novos campos/consulta mantendo o detalhe atual do filme intacto.

### T3 — Exibir e navegar pela coleção

- **Agente recomendado:** `mobile-developer`
- **Skill recomendada:** `app-builder`
- **Prioridade:** P2
- **Dependências:** T2
- **Entrada:** modelo e serviço de coleção aprovados.
- **Saída:** seção de coleção em detalhes de filme e tela com a lista sequenciada; rota GoRouter; seleção abre os detalhes comuns.
- **Verificação:** validar estados de carregamento, vazio e erro, navegação para um item e foco/controle remoto na TV.
- **Recuperação:** ocultar a seção e a rota sem alterar o restante da tela de detalhes ou a reprodução.

### T4 — Validar exemplos e documentar comportamento

- **Agente recomendado:** `test-engineer`
- **Skill recomendada:** `plan-writing`
- **Prioridade:** P3
- **Dependências:** T2 e T3
- **Entrada:** implementação integrada.
- **Saída:** cobertura de testes, nota curta na documentação de continuidade/coleções e checklist de validação.
- **Verificação:** testes focados e `flutter analyze` aprovados; a suíte completa foi executada, mas 6 testes de Cast falharam por problemas de WebView/asserções da ponte nativa.
- **Recuperação:** corrigir ou reverter apenas o escopo de coleções, sem mexer na continuidade de episódios.

## Riscos e limites

- A lista de entrada é curada; ela não representa todas as franquias cadastradas no TMDB. Dentro de cada coleção, a primeira versão mostra fielmente os dados da fonte e não inventa inclusões.
- “Ordem correta” pode significar lançamento ou cronologia da história. O plano recomenda lançamento por ser objetiva e verificável; ordem narrativa exigiria regras editoriais ou exceções mantidas manualmente.
- Títulos fornecidos por plugins sem ID TMDB não ganham associação automática nesta entrega.
- A disponibilidade para reprodução continua dependente dos provedores atuais, não da existência do filme na coleção.

## Fase X — Verificação final

- [x] Ordem de lançamento implementada como padrão aprovado para a execução.
- [x] Testes unitários para associação TMDB, resposta válida, ordenação, data ausente e falha de rede.
- [x] Teste automatizado da navegação coleção → filme → detalhes.
- [x] `flutter analyze --no-pub` sem problemas.
- [ ] `flutter test --no-pub` aprovado em `cinemax/`; a execução terminou com 6 falhas nos testes de Cast/WebView e ponte nativa.
- [ ] Verificar Velozes e Furiosos, Harry Potter e Shrek numa sessão estável do TMDB; as consultas ao vivo foram intermitentes.
- [ ] Verificar navegação por controle remoto em Android TV; não havia dispositivo Android/TV conectado.
- [x] Não gerar APK sem solicitação explícita; nenhum arquivo protegido de Cast foi alterado.
