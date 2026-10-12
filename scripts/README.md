# Scripts do projeto

Execute os comandos abaixo na raiz do repositório. Os scripts de publicação
publicam as variantes mobile e TV e devem ser usados somente quando for lançar uma versão.

## Testes do banco de contas

Com Docker em execução:

```powershell
.\scripts\test_accounts_database.ps1
```

Cria um PostgreSQL isolado, valida a migração e as regras de acesso entre contas
e remove o contêiner de teste. Não acessa o Supabase remoto nem publica APKs.
Veja o [guia de contas e favoritos](../docs/contas-supabase.md).

## Publicação Mobile em um Clique

Com o repositório na `main` atualizada, árvore limpa e `gh auth login`
configurado, dê duplo clique em `scripts/publicar-mobile.bat`.

O launcher executa `publish_release.ps1`, incrementa versão/build, cria commit e
tag, envia a `main` antes da tag e acompanha a compilação e publicação no GitHub Actions
e baixa o APK para `releases/mobile/`. O tamanho e SHA-256 do download são
comparados aos assets remotos antes de substituir a cópia local anterior.

O script não sobrescreve tags e se recusa a publicar com uma árvore suja ou
`main` desatualizada. Se o workflow falhar depois de a tag ser enviada, execute
novamente na mesma árvore limpa para tentar concluir essa versão.

Para validar ferramentas e autenticação sem publicar:

```powershell
.\scripts\publish_release.ps1 -PreflightOnly
```

Para informar manualmente a versão ou as notas, passe `-Version` e `-Notes` ao
script PowerShell.

## Publicação pelo GitHub Actions

Os fluxos de release preparam a assinatura, instalam dependências, compilam e
publicam o APK com SHA-256. A senha da chave é conferida antes da compilação.
Análise e testes ficam no workflow `CI`, sem repetição nos publicadores ou nas
releases. O mobile exige apenas Git e GitHub CLI; o publicador TV também usa Node.js.

```powershell
.\scripts\publish_release.ps1 -Version "1.0.10" -Notes "Descrição da atualização"
```

O script atualiza a versão de `cinemax/pubspec.yaml` e envia o commit e a tag
que acionam `.github/workflows/release.yml`. A assinatura usa os secrets já
configurados no repositório. A compilação acontece no GitHub; Flutter não é necessário na máquina local.

## Publicação Android TV

O publicador TV usa o workflow assinado do GitHub Actions. Valide sem publicar:

```powershell
node scripts/publish-tv.js --preflight-only
```

Para publicar a próxima versão, execute `node scripts/publish-tv.js`; também é
possível informar uma versão `X.Y.Z`. O fluxo exige a branch `main` atualizada
e uma árvore limpa, atualiza
`cinemax_tv/pubspec.yaml` e o inventário, cria commit e tag `tv-vX.Y.Z`, envia
`main` antes da tag e acompanha o workflow. O APK assinado e o checksum SHA-256
são validados antes de atualizar `releases/tv/`. Falhas preservam a tag para
retentativa; não há build ou upload local.

## Publicação com APK local

```powershell
node scripts/publish-release.js 1.0.10 --build
```

O script compila e publica o APK, guardando uma única cópia de distribuição em
`releases/mobile/`. Sem `--build`, reutiliza o APK com a versão solicitada quando
ele já existe nessa pasta; caso contrário, compila essa versão. Após o upload
bem-sucedido, mantém a maior versão mobile nessa pasta e remove as anteriores.
Republicar uma versão antiga preserva o APK de versão superior que já esteja salvo.

Os arquivos em `cinemax/build/` são saídas intermediárias do Flutter. APKs de TV
publicados ficam em `releases/tv/`; a publicação mobile não os modifica.

Consulte a [organização dos APKs](../releases/README.md) e as
[regras de publicação](../cinemax/regras/04-politica-build-e-releases.md).
