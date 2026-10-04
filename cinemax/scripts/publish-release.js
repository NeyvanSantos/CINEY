const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Diretórios e Caminhos
const SCRIPT_DIR = __dirname;
const CINEMAX_DIR = path.resolve(SCRIPT_DIR, '..');
const ROOT_DIR = path.resolve(CINEMAX_DIR, '..');
const PUBSPEC_PATH = path.join(CINEMAX_DIR, 'pubspec.yaml');
const REPO_SLUG = 'NeyvanSantos/CINEY';

/**
 * Obtém o token do GitHub diretamente do Windows Credential Manager / Git.
 */
function getGitHubToken() {
  try {
    const out = execSync('git credential fill', {
      input: 'protocol=https\nhost=github.com\n\n',
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'ignore'],
    });
    const match = out.match(/password=(.+)/);
    if (match && match[1]) {
      return match[1].trim();
    }
  } catch {
    // Silencioso se falhar
  }
  return process.env.GH_TOKEN || process.env.GITHUB_TOKEN || null;
}

/**
 * Executa comandos no shell com exibição ao vivo e retorno.
 */
function run(cmd, cwd = ROOT_DIR, env = {}) {
  return execSync(cmd, {
    cwd: cwd,
    stdio: 'inherit',
    env: { ...process.env, ...env },
    encoding: 'utf-8',
  });
}

/**
 * Executa comando e retorna a saída em texto.
 */
function runOutput(cmd, cwd = ROOT_DIR) {
  try {
    return execSync(cmd, { cwd: cwd, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'ignore'] }).trim();
  } catch {
    return '';
  }
}

/**
 * Compila o APK de release contornando caminhos com acentos no Windows via subst virtual drive.
 */
function buildReleaseApk() {
  console.log('\n🔨 [CineMax] Compilando APK de Release oficial (Flutter AOT)...');
  const tempDrive = 'X:';

  try {
    // Cria mapeamento temporário para contornar caracteres acentuados no caminho
    try {
      execSync(`subst ${tempDrive} /d`, { stdio: 'ignore' });
    } catch {}
    execSync(`subst ${tempDrive} "${ROOT_DIR}"`, { stdio: 'inherit' });

    const virtualCinemax = `${tempDrive}\\cinemax`;
    console.log(`📍 Compilando na unidade virtual: ${virtualCinemax}`);

    run('flutter build apk --release --no-tree-shake-icons', virtualCinemax);
    console.log('✅ Compilação do APK concluída com sucesso!');
  } finally {
    try {
      execSync(`subst ${tempDrive} /d`, { stdio: 'ignore' });
    } catch {}
  }
}

/**
 * Gera automaticamente o changelog com base no histórico recente de commits do Git.
 */
function generateChangelog() {
  try {
    const tags = runOutput('git tag --sort=-creatordate')
      .split('\n')
      .map((t) => t.trim())
      .filter(Boolean);

    let logCmd = 'git log -n 15 --pretty=format:"%s"';
    if (tags.length > 1) {
      const prevTag = tags[1];
      logCmd = `git log ${prevTag}..HEAD --pretty=format:"%s"`;
    }

    const commits = runOutput(logCmd)
      .split('\n')
      .map((c) => c.trim())
      .filter(Boolean);

    if (commits.length === 0) return '';

    const feats = [];
    const fixes = [];
    const docs = [];
    const others = [];

    for (const msg of commits) {
      if (/^feat(\([^)]+\))?:\s*/i.test(msg)) {
        feats.push(msg.replace(/^feat(\([^)]+\))?:\s*/i, ''));
      } else if (/^fix(\([^)]+\))?:\s*/i.test(msg)) {
        fixes.push(msg.replace(/^fix(\([^)]+\))?:\s*/i, ''));
      } else if (/^docs(\([^)]+\))?:\s*/i.test(msg)) {
        docs.push(msg.replace(/^docs(\([^)]+\))?:\s*/i, ''));
      } else if (!/^chore\(release\)/i.test(msg)) {
        others.push(msg);
      }
    }

    let notes = '';
    if (feats.length > 0) {
      notes += '### 🚀 Novidades e Novos Recursos\n';
      notes += feats.map((f) => `- ${f}`).join('\n') + '\n\n';
    }
    if (fixes.length > 0) {
      notes += '### 🐛 Correções e Melhorias\n';
      notes += fixes.map((f) => `- ${f}`).join('\n') + '\n\n';
    }
    if (docs.length > 0) {
      notes += '### 📚 Documentação e Regras\n';
      notes += docs.map((d) => `- ${d}`).join('\n') + '\n\n';
    }
    if (others.length > 0 && feats.length === 0 && fixes.length === 0) {
      notes += '### 📝 Alterações nesta Versão\n';
      notes += others.map((o) => `- ${o}`).join('\n') + '\n\n';
    }

    return notes;
  } catch {
    return '';
  }
}

function main() {
  console.log('\n🎬 [CineMax] Publicador de Releases no GitHub com Changelog e APK...\n');

  // 1. Ler e atualizar pubspec.yaml
  let pubspecContent = fs.readFileSync(PUBSPEC_PATH, 'utf-8');
  let currentVersion = '1.0.0';
  let currentBuild = 1;

  const versionMatch = pubspecContent.match(/version:\s*(\d+\.\d+\.\d+)\+(\d+)/);
  if (versionMatch) {
    currentVersion = versionMatch[1];
    currentBuild = parseInt(versionMatch[2], 10);
  }

  // Permite passar versão como argumento (ex: node publish-release.js 1.0.1)
  const argVersion = process.argv.find((a) => /^\d+\.\d+\.\d+$/.test(a));
  let version = argVersion || currentVersion;

  if (argVersion && argVersion !== currentVersion) {
    const newBuild = currentBuild + 1;
    const newVersionLine = `version: ${version}+${newBuild}`;
    pubspecContent = pubspecContent.replace(/version:\s*.*/, newVersionLine);
    fs.writeFileSync(PUBSPEC_PATH, pubspecContent, 'utf-8');
    console.log(`📌 Versão atualizada no pubspec.yaml para: v${version} (Build ${newBuild})`);

    // Comita o bump de versão
    try {
      run(`git add cinemax/pubspec.yaml`);
      run(`git commit -m "chore(release): bump version to v${version} [skip ci]"`);
      run(`git push origin main`);
    } catch {}
  } else {
    console.log(`📌 Versão alvo: v${version}`);
  }

  // 2. Verificar ou compilar APK de Release
  const builtApkPath = path.join(CINEMAX_DIR, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
  const namedApkPath = path.join(CINEMAX_DIR, `CiNey-v${version}.apk`);
  const rootApkPath = path.join(ROOT_DIR, `CiNey-v${version}.apk`);

  const shouldBuild = !fs.existsSync(builtApkPath) && !fs.existsSync(namedApkPath) || process.argv.includes('--build');

  if (shouldBuild) {
    buildReleaseApk();
  }

  // Copia o APK para o nome de distribuição se necessário
  let finalApkToUpload = namedApkPath;
  if (fs.existsSync(builtApkPath)) {
    fs.copyFileSync(builtApkPath, namedApkPath);
    fs.copyFileSync(builtApkPath, rootApkPath);
  } else if (!fs.existsSync(namedApkPath)) {
    if (fs.existsSync(rootApkPath)) {
      finalApkToUpload = rootApkPath;
    } else {
      console.error(`❌ Erro: O APK de release não foi encontrado.`);
      process.exit(1);
    }
  }

  const apkStats = fs.statSync(finalApkToUpload);
  const apkSizeMb = (apkStats.size / (1024 * 1024)).toFixed(1);
  console.log(`✅ APK localizado: "${finalApkToUpload}" (${apkSizeMb} MB)`);

  // 3. Obter token de autenticação
  const token = getGitHubToken();
  if (!token) {
    console.error('❌ Erro: Não foi possível obter o token de autenticação do GitHub.');
    console.error('Execute "gh auth login" ou verifique suas credenciais do Git.');
    process.exit(1);
  }

  const tag = `v${version}`;
  const title = `CineMax ${tag}`;

  // 4. Montar Changelog / O que foi alterado
  console.log('📋 Coletando lista de alterações (Changelog)...');
  const dynamicChangelog = generateChangelog();

  // Permite notas personalizadas via argumento: --notes "..."
  const notesIndex = process.argv.indexOf('--notes');
  const customNotes = notesIndex !== -1 && process.argv[notesIndex + 1] ? process.argv[notesIndex + 1] : null;

  let releaseBody = `## 🎬 CineMax ${tag}\n\n`;

  if (customNotes) {
    releaseBody += `### 📌 Destaques desta Versão:\n${customNotes}\n\n`;
  } else if (dynamicChangelog) {
    releaseBody += dynamicChangelog;
  } else {
    releaseBody += `### 🚀 Destaques:\n- Atualização de estabilidade, novas fontes e sistema de auto-atualização.\n\n`;
  }

  releaseBody += `### 📦 Como Instalar / Atualizar:\n`;
  releaseBody += `1. Baixe o APK oficial anexado abaixo (**\`CiNey-${tag}.apk\`**).\n`;
  releaseBody += `2. Instale no seu dispositivo Android ou TV.\n`;
  releaseBody += `3. Os próximos lançamentos serão detectados e atualizados **automaticamente pelo próprio aplicativo**!\n\n`;
  releaseBody += `---\n*CineMax — Filmes, Séries & Animes Sem Limites.*`;

  // Salva arquivo temporário de notas
  const notesFile = path.join(CINEMAX_DIR, 'release-notes-temp.md');
  fs.writeFileSync(notesFile, releaseBody, 'utf-8');

  // 5. Criação da Tag Git
  console.log(`🏷️  Criando e sincronizando tag ${tag}...`);
  try {
    run(`git tag -a ${tag} -m "${title}"`);
  } catch {
    console.log(`Tag ${tag} local já existe, prosseguindo...`);
  }

  try {
    run(`git push origin ${tag}`);
  } catch {
    console.log(`Tag ${tag} já está sincronizada no remoto.`);
  }

  // 6. Publicação no GitHub Releases via GitHub CLI com o Changelog e APK
  console.log(`🌐 Publicando Release ${tag} no GitHub (${REPO_SLUG}) com APK anexado...`);

  const filesToUpload = [`"${finalApkToUpload}"`];

  try {
    run(
      `gh release create ${tag} ${filesToUpload.join(' ')} --repo ${REPO_SLUG} --title "${title}" --notes-file "${notesFile}"`,
      ROOT_DIR,
      { GH_TOKEN: token }
    );
  } catch {
    console.log('⚠️ Release já existente detectada. Atualizando notas e arquivos anexados...');
    try {
      run(
        `gh release edit ${tag} --repo ${REPO_SLUG} --title "${title}" --notes-file "${notesFile}"`,
        ROOT_DIR,
        { GH_TOKEN: token }
      );
    } catch {}
    run(
      `gh release upload ${tag} ${filesToUpload.join(' ')} --repo ${REPO_SLUG} --clobber`,
      ROOT_DIR,
      { GH_TOKEN: token }
    );
  }

  // Remove arquivo temporário de notas
  try {
    fs.unlinkSync(notesFile);
  } catch {}

  console.log('\n🎉 RELEASE PUBLICADA COM SUCESSO NO GITHUB COM CHANGELOG E APK ANEXADO!');
  console.log(`🔗 Ver em: https://github.com/${REPO_SLUG}/releases/tag/${tag}\n`);
}

main();
