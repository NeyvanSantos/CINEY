# Separação mobile e TV — 15/10/2026

A implementação comum passou para `packages/ciney_core`. O host mobile
`cinemax` e o host `cinemax_tv` dependem diretamente desse pacote. A TV não
depende mais do host mobile.

| Parte | Conteúdo |
| --- | --- |
| `packages/ciney_core/lib` | Catálogo, quatro tipos de conteúdo, busca, conta, QR exibido pela TV, favoritos, histórico, fontes, player nativo, WebView TV e receptor de comandos. |
| `cinemax/lib/mobile` | Adaptadores CastLite, observador de frames e notificação Android. |
| `cinemax/lib/features/auth/presentation/tv_pairing_scanner_screen.dart` | Scanner por câmera exclusivo do celular. |
| `cinemax/lib/core`, `features`, `plugin_engine` | Exports de compatibilidade; a implementação compartilhada fica no núcleo. |
| `cinemax_tv/lib/main.dart` | Inicialização com interface e navegação de TV. |

As chaves de armazenamento, IDs dos aplicativos principais, contratos de conta,
consulta de avisos e receptor Realtime foram preservados. Não houve migração nem
alteração de dados no Supabase.

## Efeito na TV

- `castlite_engine`, `mobile_scanner`, `embed_media_observer` e
  `flutter_local_notifications` saíram das dependências de produção da TV.
- Sem Transmitir, Compartilhar sem ação ou diálogo para copiar link nos detalhes.
- A rota do scanner não é criada na TV. O QR de entrada continua disponível.
- Avisos do administrador são exibidos dentro do app, sem o plugin de
  notificação do sistema.
- Listas de lançamentos não rolam automaticamente. Cartões usam superfície
  sólida; placeholders são estáticos e o splash TV não tem espera artificial
  nem animação contínua.
- Limpar cache agora executa a limpeza de imagens em disco e memória e informa
  falhas; não apaga a conta nem o histórico.
- Release TV habilita R8 e remoção de recursos, com preservação de interfaces
  JavaScript e métodos JNI usados pelos plugins restantes.
- O botão central do controle (`Select`) aciona também superfícies e diálogos
  padrão na TV, preservando os demais atalhos do Flutter.

O mobile mantém o motor CastLite e seu botão de ícone ao lado de **Ir**, com o
mesmo fundo e largura. Mantém também scanner, observação de frames e avisos
Android. O mínimo continua Android 8 nas duas variantes.

## Validação automatizada

- 171 testes Flutter passaram, incluindo conta, pareamento, favoritos, fontes,
  episódios, retomada, receptor TV, controles D-pad e a nova separação de hosts.
- 40 testes JavaScript do player passaram.
- A lista de plugins Android TV foi conferida: 15 entradas e nenhuma dos quatro
  plugins exclusivos do celular. Seu `package_config.json` também não contém o
  host `cinemax`.
- Análise: hosts sem problemas; núcleo sem erros ou avisos, com três informes
  de estilo.
- Builds mobile debug e TV release concluídos. Metadados, arquiteturas,
  Android mínimo, assinatura e hashes dos quatro APKs conferidos.
- Imports do núcleo e exports de compatibilidade conferidos; nenhum import dos
  quatro plugins mobile no núcleo. `git diff --check` passou.

## APKs locais

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-local-mobile-tv.ps1 -Offline
```

O script usa um caminho temporário sem acentos e reconstrói o código Flutter.
Não reutiliza os assets Dart antigos da integração. São gerados o mobile debug
`com.ciney.app.castlite_test` e a TV release de teste `com.ciney.tv.lite_test`,
assinada com certificado de depuração, em `outputs/`.

Os APKs TV são separados para ARMv7, ARM64 e x86_64. A distribuição pública e o
atualizador existentes continuam usando seus canais e nomes atuais; escolher
automaticamente APK por arquitetura numa futura publicação exige alterar esse
fluxo antes de distribuir esses artefatos. Os arquivos locais de teste não são
atualizações oficiais.

### Artefatos conferidos

Todos usam a versão `1.0.39-teste-local`, exigem Android 8 (API 26) e possuem
assinatura APK v2 válida, com um único certificado de depuração. Os tamanhos
abaixo estão em MiB. O mobile é debug e universal; seus números não devem ser
comparados diretamente com os APKs TV release separados por arquitetura.

| Arquivo em `outputs/` | Arquitetura | Tamanho |
| --- | --- | --- |
| `CiNey-CastLite-BlueStacks-teste.apk` | ARMv7, ARM64 e x86_64 | 185,67 MiB |
| `CiNey-TV-Leve-teste-armeabi-v7a.apk` | ARMv7 | 20,15 MiB |
| `CiNey-TV-Leve-teste-arm64-v8a.apk` | ARM64 | 22,21 MiB |
| `CiNey-TV-Leve-teste-x86_64.apk` | x86_64 / BlueStacks | 23,63 MiB |

SHA-256 dos APKs:

```text
6557094C64D2D3677BACCCB31D8FC0224D4211A3CAEBD8E1E55FAA221D6673E8  CiNey-CastLite-BlueStacks-teste.apk
B0A3C1B44CD98A30BF859B696B1114AB6C1892FADE9E8920EE1A359BC3ACAF24  CiNey-TV-Leve-teste-armeabi-v7a.apk
F65C9DED8AB5772BB99AAB7446A1E53AC78FA503556D84B1B8B88815A3D835B7  CiNey-TV-Leve-teste-arm64-v8a.apk
FD7C646D8A68742EBB7BC32B273085DA4203635C26D7BE64CE14AC7935696A4D  CiNey-TV-Leve-teste-x86_64.apk
```

SHA-256 do certificado de teste:
`5bfb1d3a7b6547e8b260ee4e192ee5105c15a954524694b2edbd68fe85e996d2`.
Os APKs TV não declaram câmera nem `FOREGROUND_SERVICE_CONNECTED_DEVICE`.

### Conferência no BlueStacks

Os pacotes privados mobile e TV x86_64 foram instalados sem substituir os
aplicativos oficiais. Ambos iniciaram novamente nesta conferência, no
BlueStacks Pie64 com Android 9.

Na TV, foi conferida a tela de entrada com QR Code e acesso manual. As setas
mudaram o foco e o botão central (`DPAD_CENTER`, código Android 23) acionou
**Depois** no aviso de atualização e abriu o formulário de acesso manual.
Enter também foi conferido. Nenhum login foi realizado nesta validação. O
fluxo completo após autenticação e a reprodução não foram verificados no
emulador.

No mobile, a sessão já existente foi mantida: o catálogo e a página de detalhes
abriram, incluindo a ação **Transmitir**. Não foi iniciada transmissão para um
receptor físico nesta conferência.

O atualizador existente interpreta o sufixo `-teste-local` como versão anterior
à oficial `1.0.39` e oferece atualização ao iniciar. Foi escolhido **Depois**.
Para continuar avaliando estes APKs, use essa opção; instalar a atualização
oficial sai da versão local de teste. O atualizador público não foi alterado.

Capturas, árvores de acessibilidade, logs de build e metadados ficam em
`.work/dependency-separation/`, ignorado pelo Git. Não houve push, tag, release
nem publicação.

### Limite da validação

Teste em TV física ainda é necessário para comprovar imagem, som, áudio,
legendas, desempenho e navegação com o controle do aparelho. Iniciar o app num
emulador e passar nos testes não substitui essa confirmação.
