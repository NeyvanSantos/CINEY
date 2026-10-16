# Publicação mobile e TV 1.0.42 — 16/10/2026

Publicação pública dos dois aplicativos autorizada pelo usuário. As tags
`v1.0.42` e `tv-v1.0.42` apontam para o mesmo commit da `main`:
`dd82a5bf5f7d061a83fce1e5ead53a9f1355d9a4`.

| Variante | Pacote | Versão / build | APK | Tamanho |
| --- | --- | --- | --- | --- |
| Mobile | `com.ciney.app` | 1.0.42 / 39 | `CiNey-v1.0.42.apk` | 92.000.514 bytes |
| TV | `com.ciney.tv` | 1.0.42 / 44 | `CiNey-v1.0.42-TV.apk` | 63.366.119 bytes |

## Alterações

- Corrigida a conclusão das consultas de coleções: a limpeza das requisições em andamento retornava a própria Future, impedindo sua conclusão.
- As coleções carregadas na Home passam a usar o cache de produção, evitando novas consultas ao abrir os filmes.
- Falhas de consulta exibem a opção de tentar novamente antes da verificação de coleção vazia.
- O banner da TV passa a usar cartão 16:9 de 160 × 90 dp, fundo `#151530` e logo de 64 × 64 dp centralizada.
- Os builds de release regeneram o registro de plugins para excluir a dependência de testes de integração do aplicativo público.

Notas públicas: [Mobile](../../releases/notes/1.0.42-mobile.md) e
[TV](../../releases/notes/1.0.42-tv.md).

## Verificação

- [CI](https://github.com/NeyvanSantos/CINEY/actions/runs/38979409523) aprovado: análise Mobile/TV, testes Flutter, 40 testes JavaScript e 13 testes do servidor.
- [Build e publicação Mobile](https://github.com/NeyvanSantos/CINEY/actions/runs/38979620144) concluídos com sucesso.
- [Build e publicação TV](https://github.com/NeyvanSantos/CINEY/actions/runs/38979619314) concluídos com sucesso.
- Parser do certificado verificado em oito casos por workflow, incluindo a saída `V2 Signer`, certificados divergentes e assinatura inválida.
- APKs publicados baixados e conferidos por tamanho, digest do GitHub, arquivo `.sha256`, assinatura e metadados Android.
- Um único certificado oficial por APK: `5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be` (SHA-256).
- Bibliotecas Flutter e aplicativo presentes para ARMv7, ARM64 e x86_64; Android mínimo 8 / API 26.
- Downloads públicos retornaram HTTP 200 sem autenticação. O canal Mobile aponta para `v1.0.42`; o canal TV, para `tv-v1.0.42`.
- Regressão das coleções testada no Android Phone e Android TV da extensão RustDroid: cache da Home, consultas simultâneas, falha seguida de nova consulta e botão de tentar novamente.
- Ambos os APKs públicos instalados por atualização nos respectivos dispositivos da RustDroid; versões 1.0.42+39 e 1.0.42+44 confirmadas. A coleção Velozes & Furiosos abriu com filmes e anos nos dois aplicativos.
- Não houve teste de reprodução ou transmissão em aparelhos físicos neste lançamento.

As evidências detalhadas desta publicação estão em
`%TEMP%/ciney-release42/`; os testes anteriores das coleções, em
`%TEMP%/ciney-collections-20261016/`. Esses arquivos temporários não são
versionados. As cópias dos APKs publicados ficam em `releases/mobile/` e
`releases/tv/`, substituindo apenas a versão 1.0.41 local de cada variante.

```text
87e147c43793500c1ccf26c22aa2cf841ec11a0effff45113ca3134c784f5fb4  CiNey-v1.0.42.apk
d802e02dd7d166a9fe5ccd8bb6d78f1cf629975d105d3857a47c3a85fa5898d1  CiNey-v1.0.42-TV.apk
```

## Downloads

- [Mobile 1.0.42](https://github.com/NeyvanSantos/CINEY/releases/download/v1.0.42/CiNey-v1.0.42.apk)
- [Android TV 1.0.42](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.42/CiNey-v1.0.42-TV.apk)

A TV mantém `prerelease: true`, necessário para o canal de atualização TV
existente. O Mobile permanece estável e como versão mais recente.
