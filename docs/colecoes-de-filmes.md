# Coleções de filmes

Início exibe uma prateleira **Coleções** nos filtros “Todos” e “Filmes”. A
prateleira apresenta franquias conhecidas e a opção **Ver todas** abre a grade
desse catálogo. A tela de detalhes de um filme também liga à sua coleção quando
o TMDB fornece essa associação.

O TMDB oferece os filmes de uma coleção por ID, mas não um endpoint para listar
todas as coleções. Por isso, a lista de entrada usa IDs curados em
`TmdbService`; expandir esse catálogo exige acrescentar novos IDs. A Home busca
cinco coleções em destaque; “Ver todas” consulta o catálogo completo. A mesma
resposta do TMDB já inclui os filmes, que ficam em cache na memória durante a
sessão e são reutilizados ao abrir a coleção, sem repetir a consulta.
Consultas simultâneas da mesma coleção compartilham a requisição. Ao concluir
ou falhar, ela é removida das requisições em andamento sem aguardar a si mesma.
Uma falha exibe **Tentar novamente**, em vez de informar uma coleção vazia.

Os filmes são ordenados por data de lançamento crescente; filmes sem data ficam
no final e IDs são usados como desempate determinístico. Esta ordem não tenta
representar a cronologia interna da história. A navegação dos títulos volta à
tela de detalhes habitual e não altera o fluxo de reprodução.

Esta funcionalidade contempla filmes. Séries, temporadas e episódios não são
incluídos.

## Testes nos emuladores RustDroid

Os dois hosts têm `integration_test/collections_loading_test.dart`, com casos
compartilhados em `packages/ciney_core/test/collections_loading_test.dart`.
Eles exercitam o cache do cliente de produção, consultas simultâneas, falha
seguida de nova tentativa e a recuperação da tela. As respostas HTTP são
locais ao Android para que o teste não dependa da disponibilidade do TMDB.
Use o serial real do emulador Mobile ou TV aberto na RustDroid.
