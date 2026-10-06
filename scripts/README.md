# Scripts do projeto

Execute os comandos abaixo na raiz do repositório, somente quando for publicar
uma versão. Os dois scripts publicam a variante mobile.

## Publicação pelo GitHub Actions

```powershell
.\scripts\publish_release.ps1 -Version "1.0.10" -Notes "Descrição da atualização"
```

O script atualiza a versão de `cinemax/pubspec.yaml` e envia o commit e a tag
que acionam `.github/workflows/release.yml`. A assinatura usa os secrets já
configurados no repositório. O parâmetro `-BuildLocal` também compila localmente.

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
