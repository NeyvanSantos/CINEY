'use strict';

const { execFileSync, execSync } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '..');
const CINEMAX_DIR = path.join(ROOT_DIR, 'cinemax');
const TV_DIR = path.join(ROOT_DIR, 'cinemax_tv');
const TV_PUBSPEC = path.join(TV_DIR, 'pubspec.yaml');
const INVENTORY = path.join(ROOT_DIR, 'releases', 'README.md');
const RELEASE_DIR = path.join(ROOT_DIR, 'releases', 'tv');
const REPO_SLUG = 'NeyvanSantos/CINEY';
const WORKFLOW_FILE = 'release-tv.yml';
const ASSET_PREFIX = 'CiNey-v';

function execute(command, args, options) {
  if (process.platform === 'win32' && command === 'flutter') {
    // Flutter is a .bat on Windows; the command and arguments here are constants.
    return execSync([command, ...args].join(' '), options);
  }
  return execFileSync(command, args, options);
}

function run(command, args, cwd = ROOT_DIR, input) {
  try {
    return execute(command, args, {
      cwd,
      encoding: 'utf8',
      input,
      stdio: input === undefined ? 'inherit' : 'pipe',
      windowsHide: true,
    });
  } catch (error) {
    const exitCode = Number.isInteger(error.status) ? error.status : 'unknown';
    throw new Error(`${command} ${args[0] ?? ''} failed (exit code ${exitCode}).`);
  }
}

function output(command, args, cwd = ROOT_DIR) {
  try {
    return execute(command, args, {
      cwd,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    }).trim();
  } catch (error) {
    const exitCode = Number.isInteger(error.status) ? error.status : 'unknown';
    throw new Error(`${command} ${args[0] ?? ''} failed (exit code ${exitCode}).`);
  }
}

function parseArguments(args) {
  const preflightOnly = args.includes('--preflight-only');
  const positional = args.filter((arg) => arg !== '--preflight-only');
  if (positional.some((arg) => arg.startsWith('-')) || positional.length > 1) {
    throw new Error(
      'Uso: node scripts/publish-tv.js [X.Y.Z] [--preflight-only].',
    );
  }
  if (positional.length === 1 && !/^\d+\.\d+\.\d+$/.test(positional[0])) {
    throw new Error('A versão deve usar o formato X.Y.Z.');
  }
  return { preflightOnly, requestedVersion: positional[0] ?? null };
}

function parseVersion(pubspec) {
  const match = pubspec.match(/^version:[ \t]*(\d+\.\d+\.\d+)\+(\d+)[ \t]*$/m);
  if (!match) {
    throw new Error('Não foi possível ler a versão de cinemax_tv/pubspec.yaml.');
  }
  return { version: match[1], build: Number(match[2]) };
}

function nextPatch(version) {
  const [major, minor, patch] = version.split('.').map(Number);
  return `${major}.${minor}.${patch + 1}`;
}

function compareVersions(left, right) {
  const leftParts = left.split('.').map(Number);
  const rightParts = right.split('.').map(Number);
  for (let index = 0; index < 3; index += 1) {
    if (leftParts[index] !== rightParts[index]) {
      return leftParts[index] - rightParts[index];
    }
  }
  return 0;
}

function getRemoteTagLines(tag) {
  const ref = `refs/tags/${tag}`;
  return output('git', ['ls-remote', '--tags', 'origin', ref, `${ref}^{}`])
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function getRelease(tag) {
  try {
    return JSON.parse(
      output('gh', [
        'release',
        'view',
        tag,
        '--repo',
        REPO_SLUG,
        '--json',
        'tagName,assets,url',
      ]),
    );
  } catch {
    return null;
  }
}

function hasUploadedAsset(release, name) {
  return Boolean(
    release?.assets?.some(
      (asset) => asset.name === name && asset.state === 'uploaded' && asset.size > 0,
    ),
  );
}

function assertToolsAndAuth() {
  for (const [command, args] of [
    ['git', ['--version']],
    ['gh', ['--version']],
    ['flutter', ['--version']],
    ['node', ['--version']],
  ]) {
    output(command, args);
  }
  try {
    execFileSync('gh', ['auth', 'status', '--hostname', 'github.com'], {
      cwd: ROOT_DIR,
      stdio: 'ignore',
      windowsHide: true,
    });
  } catch {
    throw new Error('Autenticação do GitHub indisponível no GitHub CLI.');
  }
}

function validateMain() {
  const branch = output('git', ['branch', '--show-current']);
  if (branch !== 'main') {
    throw new Error('Publique somente a partir da branch main.');
  }
  const remote = output('git', ['remote', 'get-url', 'origin']);
  if (!/github\.com[:/]NeyvanSantos\/CINEY(?:\.git)?$/i.test(remote)) {
    throw new Error(`origin não aponta para github.com/${REPO_SLUG}.`);
  }
  run('git', ['fetch', 'origin']);
  const behind = Number(output('git', ['rev-list', '--count', 'main..origin/main']));
  if (behind > 0) {
    throw new Error(`main está atrás ou divergiu de origin/main em ${behind} commit(s).`);
  }
  const localCommits = output('git', ['log', '--oneline', 'origin/main..main']);
  if (localCommits) {
    console.log('Commits locais da main ainda não enviados; serão incluídos na publicação:');
    console.log(localCommits);
  }
  output('git', ['var', 'GIT_AUTHOR_IDENT']);
}

function updateInventory(version) {
  const content = fs.readFileSync(INVENTORY, 'utf8');
  const rowPattern = /^\| Android TV \| `tv\/` \| `CiNey-v\d+\.\d+\.\d+-TV\.apk` \|[ \t]*(?=\r?$)/m;
  const matches = content.match(rowPattern) ?? [];
  if (matches.length !== 1) {
    throw new Error('Não foi encontrada uma única linha Android TV em releases/README.md.');
  }
  return content.replace(
    rowPattern,
    `| Android TV | \`tv/\` | \`CiNey-v${version}-TV.apk\` |`,
  );
}

function replaceTvVersion(pubspec, version, build) {
  const pattern = /^version:[ \t]*\d+\.\d+\.\d+\+\d+[ \t]*(?=\r?$)/m;
  if (!pattern.test(pubspec)) {
    throw new Error('Não foi encontrada a linha version em cinemax_tv/pubspec.yaml.');
  }
  return pubspec.replace(pattern, `version: ${version}+${build}`);
}

function assertCleanTree() {
  const status = output('git', ['status', '--porcelain', '--untracked-files=all']);
  if (status) {
    console.error('Existem alterações locais. Faça commit antes de publicar:');
    console.error(status);
    throw new Error('Publicação cancelada para não incluir alterações inesperadas.');
  }
}

function runQualityGates() {
  run('flutter', ['analyze'], CINEMAX_DIR);
  run('flutter', ['analyze'], TV_DIR);
  run(
    'flutter',
    [
      'test',
      '--no-pub',
      'test/details_auto_play_test.dart',
      'test/player_episode_continuity_test.dart',
    ],
    CINEMAX_DIR,
  );
  run('flutter', ['test', '--no-pub'], CINEMAX_DIR);
  run(
    'node',
    [
      '--test',
      'test/embed_bridge_test.cjs',
      'test/embed_media_observer_test.cjs',
      'test/embed_startup_test.cjs',
    ],
    CINEMAX_DIR,
  );
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function parseChecksum(content, assetName) {
  const match = content.trim().match(
    new RegExp(`^([0-9a-fA-F]{64}) [ *]${escapeRegex(assetName)}$`),
  );
  if (!match) throw new Error(`Checksum inválido para ${assetName}.`);
  return match[1].toLowerCase();
}

async function delay(milliseconds) {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function listRuns(tag) {
  return JSON.parse(
    output('gh', [
      'run',
      'list',
      '--repo',
      REPO_SLUG,
      '--workflow',
      WORKFLOW_FILE,
      '--branch',
      tag,
      '--limit',
      '20',
      '--json',
      'databaseId,headSha,status,conclusion,event,createdAt',
    ]),
  );
}

function findMatchingRun(runs, commit, startTime, event) {
  return runs
    .filter(
      (candidate) =>
        candidate.headSha === commit &&
        candidate.event === event &&
        Date.parse(candidate.createdAt) >= startTime - 5000,
    )
    .sort((left, right) => Date.parse(left.createdAt) - Date.parse(right.createdAt))[0];
}

async function waitForRun(tag, commit, startTime, event) {
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const match = findMatchingRun(listRuns(tag), commit, startTime, event);
    if (match) return String(match.databaseId);
    if (attempt < 5) await delay(5000);
  }
  throw new Error(`Workflow solicitado, mas não encontrei execução para ${tag} e o commit da tag.`);
}

function getAsset(release, assetName) {
  const asset = release.assets?.find(
    (entry) => entry.name === assetName && entry.state === 'uploaded',
  );
  if (!asset || asset.size <= 0) {
    throw new Error(`A release não contém o asset ${assetName}.`);
  }
  return asset;
}

function keepLatestTvApk(version) {
  for (const file of fs.readdirSync(RELEASE_DIR)) {
    const match = file.match(/^CiNey-v(\d+\.\d+\.\d+)-TV\.apk$/);
    if (!match || file === `${ASSET_PREFIX}${version}-TV.apk`) continue;
    if (compareVersions(match[1], version) < 0) {
      fs.rmSync(path.join(RELEASE_DIR, file), { force: true });
    }
  }
}

async function downloadAndValidate(tag, version, release) {
  const assetName = `${ASSET_PREFIX}${version}-TV.apk`;
  const checksumName = `${assetName}.sha256`;
  const asset = getAsset(release, assetName);
  getAsset(release, checksumName);
  const downloadDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ciney-tv-release-'));
  try {
    run('gh', [
      'release', 'download', tag, '--repo', REPO_SLUG,
      '--pattern', assetName, '--pattern', checksumName, '--dir', downloadDir,
    ]);
    const apkPath = path.join(downloadDir, assetName);
    const checksumPath = path.join(downloadDir, checksumName);
    if (!fs.existsSync(apkPath) || fs.statSync(apkPath).size !== asset.size) {
      throw new Error('O APK TV baixado diverge do tamanho informado pelo GitHub.');
    }
    const actualHash = crypto
      .createHash('sha256')
      .update(fs.readFileSync(apkPath))
      .digest('hex');
    const checksumHash = parseChecksum(fs.readFileSync(checksumPath, 'utf8'), assetName);
    if (actualHash !== checksumHash) {
      throw new Error('O SHA-256 do APK TV diverge do arquivo checksum publicado.');
    }
    if (asset.digest) {
      const digestMatch = asset.digest.match(/^sha256:([0-9a-fA-F]{64})$/);
      if (!digestMatch || digestMatch[1].toLowerCase() !== actualHash) {
        throw new Error('O SHA-256 do APK TV diverge do digest do GitHub.');
      }
    }

    fs.mkdirSync(RELEASE_DIR, { recursive: true });
    const destination = path.join(RELEASE_DIR, assetName);
    const pending = `${destination}.${process.pid}.pending`;
    fs.copyFileSync(apkPath, pending);
    fs.rmSync(destination, { force: true });
    fs.renameSync(pending, destination);
    keepLatestTvApk(version);
    console.log(`APK TV publicado e validado: ${destination}`);
    console.log(`SHA-256: ${actualHash}`);
    console.log(`GitHub: ${release.url}`);
  } finally {
    fs.rmSync(downloadDir, { recursive: true, force: true });
  }
}

async function main() {
  const { preflightOnly, requestedVersion } = parseArguments(process.argv.slice(2));
  assertToolsAndAuth();
  validateMain();
  const branch = output('git', ['branch', '--show-current']);
  const pubspec = fs.readFileSync(TV_PUBSPEC, 'utf8');
  const current = parseVersion(pubspec);
  const currentTag = `tv-v${current.version}`;
  const currentRemoteLines = getRemoteTagLines(currentTag);
  const currentRelease = currentRemoteLines.length > 0 ? getRelease(currentTag) : null;
  const currentAsset = `${ASSET_PREFIX}${current.version}-TV.apk`;
  const currentReleaseHasApk = hasUploadedAsset(currentRelease, currentAsset);
  let version = requestedVersion ?? nextPatch(current.version);
  let retryCurrentTag = false;
  let pushLocalCurrentTag = false;

  if (!requestedVersion && currentRemoteLines.length > 0 && !currentReleaseHasApk) {
    version = current.version;
    retryCurrentTag = true;
  } else if (
    !requestedVersion &&
    currentRemoteLines.length === 0 &&
    output('git', ['tag', '--list', currentTag])
  ) {
    const localCommit = output('git', ['rev-parse', `${currentTag}^{commit}`]);
    const headCommit = output('git', ['rev-parse', 'HEAD']);
    if (localCommit !== headCommit) {
      throw new Error(`A tag local ${currentTag} não aponta para HEAD e não existe no remoto.`);
    }
    version = current.version;
    retryCurrentTag = true;
    pushLocalCurrentTag = true;
  }

  if (!/^\d+\.\d+\.\d+$/.test(version)) {
    throw new Error('Versão inválida; use o formato X.Y.Z.');
  }
  if (!retryCurrentTag && compareVersions(version, current.version) <= 0) {
    throw new Error(`A versão alvo ${version} deve ser maior que ${current.version}.`);
  }
  const tag = `tv-v${version}`;
  let tagCommit = null;

  if (retryCurrentTag) {
    if (pushLocalCurrentTag) {
      tagCommit = output('git', ['rev-parse', `${currentTag}^{commit}`]);
    } else {
      const peeled = currentRemoteLines.find((line) =>
        line.endsWith(`\trefs/tags/${currentTag}^{}`),
      );
      if (peeled) {
        tagCommit = peeled.split(/\s+/)[0];
      } else {
        run('git', ['fetch', '--quiet', 'origin', `refs/tags/${currentTag}:refs/tags/${currentTag}`]);
        tagCommit = output('git', ['rev-parse', `${currentTag}^{commit}`]);
      }
    }
    if (tagCommit !== output('git', ['rev-parse', 'HEAD'])) {
      throw new Error(`A tag ${currentTag} não aponta para o código atual; retentativa recusada.`);
    }
  } else {
    const targetRemote = getRemoteTagLines(tag);
    if (targetRemote.length > 0 || output('git', ['tag', '--list', tag])) {
      throw new Error(`A tag ${tag} já existe; tags/releases não são sobrescritas.`);
    }
  }

  console.log('===================================================');
  console.log(' CiNey TV - Publicação segura via GitHub Actions');
  console.log(` Branch: ${branch} (validada contra origin/main)`);
  console.log(` Versão atual: ${current.version}+${current.build}`);
  console.log(` Versão alvo: ${tag}`);
  console.log(' Build assinado e release: GitHub Actions');
  console.log('===================================================');

  if (preflightOnly) {
    const status = output('git', ['status', '--porcelain', '--untracked-files=all']);
    if (status) {
      console.log('Preflight OK; antes de publicar, faça commit das alterações:');
      console.log(status);
    } else {
      console.log('Preflight OK; main limpa e atualizada. Nenhuma tag ou workflow criado.');
    }
    return;
  }

  const status = output('git', ['status', '--porcelain', '--untracked-files=all']);
  if (status) {
    console.error('Existem alterações locais. Faça commit antes de publicar:');
    console.error(status);
    throw new Error('Publicação cancelada para não incluir alterações inesperadas.');
  }

  if (!retryCurrentTag) {
    runQualityGates();
    const newBuild = current.build + 1;
    const updatedPubspec = replaceTvVersion(pubspec, version, newBuild);
    const updatedInventory = updateInventory(version);
    fs.writeFileSync(TV_PUBSPEC, updatedPubspec, 'utf8');
    fs.writeFileSync(INVENTORY, updatedInventory, 'utf8');
    run('git', ['add', '--', 'cinemax_tv/pubspec.yaml', 'releases/README.md']);
    run('git', ['commit', '-m', `chore(release): bump TV version to ${tag} [skip ci]`]);
    run('git', ['tag', '-a', tag, '-m', `Release TV ${tag}`]);
    tagCommit = output('git', ['rev-parse', `${tag}^{commit}`]);
  }

  try {
    run('git', ['push', 'origin', 'main']);
  } catch {
    throw new Error(`Push da main recusado. A tag ${tag} foi preservada localmente; resolva a proteção e retente.`);
  }
  if (!retryCurrentTag || pushLocalCurrentTag) {
    try {
      run('git', ['push', 'origin', tag]);
    } catch {
      throw new Error(`A main foi enviada, mas a tag ${tag} não. Execute novamente para retomar.`);
    }
  }

  const runList = listRuns(tag);
  const activeRun = runList.find(
    (candidate) =>
      candidate.headSha === tagCommit &&
      ['queued', 'in_progress'].includes(candidate.status),
  );
  let runId = activeRun ? String(activeRun.databaseId) : null;

  if (!runId && retryCurrentTag) {
    const dispatchStart = Date.now();
    const dispatchInput = JSON.stringify({
      version_tag: tag,
      release_notes: 'Retentativa da publicação CiNey para Android TV.',
    });
    const dispatchOutput = run(
      'gh',
      ['workflow', 'run', WORKFLOW_FILE, '--repo', REPO_SLUG, '--ref', tag, '--json'],
      ROOT_DIR,
      `${dispatchInput}\n`,
    );
    console.log(dispatchOutput.trim());
    const runMatch = dispatchOutput.match(/\/actions\/runs\/(\d+)/);
    runId = runMatch?.[1] ?? null;
    if (!runId) {
      runId = await waitForRun(tag, tagCommit, dispatchStart, 'workflow_dispatch');
    }
  } else if (!runId) {
    runId = await waitForRun(tag, tagCommit, Date.now() - 10000, 'push');
  }

  run('gh', ['run', 'watch', runId, '--repo', REPO_SLUG, '--exit-status']);
  const release = getRelease(tag);
  if (!release || release.tagName !== tag) {
    throw new Error(`A release ${tag} não foi encontrada após o workflow.`);
  }
  await downloadAndValidate(tag, version, release);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
