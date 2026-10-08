<p align="center">
	<img src="assets/images/logo.png" alt="Logo CiNey" width="180">
</p>

<h1 align="center">CiNey</h1>

<p align="center">Descubra seu próximo filme ou série com busca simples, catálogo organizado e uma experiência feita para celular e TV.</p>

<p align="center">
	<a href="https://github.com/NeyvanSantos/CINEY/releases">Ver releases</a>
</p>

## Sobre o CiNey

CiNey reúne catálogo, busca e reprodução em um aplicativo Flutter. Você pode explorar títulos por categorias, pesquisar por nome e filtrar resultados entre **filmes, séries, animes e doramas**. O catálogo combina consultas ao TMDB com fontes organizadas pelo motor de plugins do projeto.

A busca aceita sugestões enquanto você digita e permite abrir os detalhes do título para consultar as opções disponíveis. A disponibilidade de cada conteúdo depende do catálogo e dos serviços externos utilizados.

## Recursos

- **Descoberta rápida:** catálogo inicial organizado por temas e categorias.
- **Busca com filtros:** encontre títulos e refine resultados por tipo de conteúdo.
- **Filmes e séries:** consulte detalhes e, quando disponíveis, temporadas e episódios.
- **Fontes de reprodução:** escolha entre as fontes externas disponibilizadas para o título.
- **Diagnóstico integrado:** console de logs com pesquisa e filtros para ajudar a investigar problemas.
- **Android TV:** navegação lateral adaptada ao controle remoto e teclas de mídia no player.
- **Contas e favoritos:** cadastro, perfil e lista compartilhada entre celular e TV, após [configurar o Supabase](../docs/contas-supabase.md).
- **Atualizações:** verificação de releases do projeto e validação SHA-256 quando o hash está disponível.

## Uma base, duas experiências

O projeto [`cinemax/`](.) é a fonte única das telas, serviços, motor de plugins e assets Flutter. O projeto [`cinemax_tv/`](../cinemax_tv/README.md) mantém somente o host Android TV: manifesto, launcher Leanback, banner e configurações específicas da plataforma. Assim, melhorias na base podem ser compartilhadas entre celular e TV, enquanto cada variante conserva seu identificador e canal de atualização.

## Segurança e privacidade

É necessário criar uma conta ou entrar para usar o aplicativo, no celular e na
TV. Na primeira entrada, o cadastro é apresentado antes do catálogo. Uma sessão
salva permite entrar automaticamente nos acessos seguintes; sair da conta ou
perder a sessão exige autenticação novamente. O Supabase armazena o perfil
e os favoritos de cada usuário. A sessão fica no armazenamento seguro do
dispositivo; senhas não são salvas pelo aplicativo. É possível excluir a conta
e seus dados em **Perfil → Gerenciar conta**.

CiNey precisa de conexão com a internet para consultar catálogos, pesquisar títulos, carregar fontes e verificar atualizações. O aplicativo não hospeda os vídeos: a reprodução pode abrir conteúdo de provedores externos em uma WebView. As práticas de privacidade, a disponibilidade, a qualidade e os anúncios desses serviços são responsabilidade de cada provedor; o app não certifica nem garante o conteúdo externo.

O atualizador consulta as releases do repositório oficial e compara o SHA-256 quando a release fornece esse valor. A instalação de um APK externo pode exigir a permissão do Android para instalar aplicativos, solicitada pelo sistema quando necessária.

O console guarda até 500 registros em memória durante a sessão; eles são apagados quando o processo do aplicativo é encerrado. Registros de erro podem incluir detalhes técnicos e pilhas de execução. Revise essas informações antes de compartilhá-las.

## Transmissão

A opção **Transmitir** utiliza o fluxo de espelhamento de tela pelo Google Home para reproduções incorporadas. O endereço HTML de um provedor não é enviado ao receptor como se fosse um arquivo de vídeo. É necessário que celular e TV estejam na mesma rede Wi-Fi; consulte as [instruções do Google Cast](https://support.google.com/googlecast/answer/6059461?hl=pt-BR).

## Executar localmente

### Contas e favoritos

O app inclui cadastro, login, recuperação de senha, perfil editável e favoritos
sincronizados entre celular e TV. Antes de usar as contas, aplique a migração do
banco e configure os e-mails seguindo o [guia do Supabase](../docs/contas-supabase.md).
O cadastro ou login é obrigatório antes da configuração inicial e do catálogo.
Na TV, também é possível entrar pelo pareamento com o Android.

Requisitos: Flutter com Dart 3.11.4 ou superior e Android SDK configurado.

App principal:

```powershell
cd cinemax
flutter pub get
flutter run
```

Android TV:

```powershell
cd cinemax_tv
flutter pub get
flutter run
```

## Testes e análise

Execute a partir de `cinemax/`:

```powershell
flutter analyze
flutter test --no-pub
node --test test/embed_bridge_test.cjs
```

## Estrutura do projeto

- `lib/core/`: configuração, navegação, serviços e componentes compartilhados.
- `lib/features/`: telas e recursos organizados por funcionalidade.
- `lib/plugin_engine/`: catálogo, plugins e resolução de fontes.
- `assets/`: logo e recursos usados pelo aplicativo.
- `../cinemax_tv/android/`: configuração nativa exclusiva da Android TV.

## Releases

Consulte as [releases oficiais do CiNey](https://github.com/NeyvanSantos/CINEY/releases). Os canais mobile e TV são separados; as releases TV usam tags `tv-vX.Y.Z` e são publicadas como pré-lançamentos.
