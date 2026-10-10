# Coleções de filmes

Início exibe uma prateleira **Coleções** nos filtros “Todos” e “Filmes”. A
prateleira apresenta franquias conhecidas e a opção **Ver todas** abre a grade
desse catálogo. A tela de detalhes de um filme também liga à sua coleção quando
o TMDB fornece essa associação.

O TMDB oferece os filmes de uma coleção por ID, mas não um endpoint para listar
todas as coleções. Por isso, a lista de entrada usa IDs curados em
`TmdbService`; expandir esse catálogo exige acrescentar novos IDs. A Home busca
metadados das cinco coleções em destaque; “Ver todas” consulta o catálogo
completo e os filmes só são carregados ao abrir uma coleção. Os dados vêm do
TMDB em português e ficam em cache na memória durante a sessão.

Os filmes são ordenados por data de lançamento crescente; filmes sem data ficam
no final e IDs são usados como desempate determinístico. Esta ordem não tenta
representar a cronologia interna da história. A navegação dos títulos volta à
tela de detalhes habitual e não altera o fluxo de reprodução.

Esta funcionalidade contempla filmes. Séries, temporadas e episódios não são
incluídos.