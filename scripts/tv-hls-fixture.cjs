// Local-only fixture for the Android TV integration test. No external media.
// node scripts/tv-hls-fixture.cjs <generated HLS directory> [port]
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { randomBytes } = require('node:crypto');
const root = path.resolve(process.argv[2] || '.work/tv-hls-fixture');
const port = Number(process.argv[3] || 8879);
if (!fs.existsSync(path.join(root, 'film.m3u8'))) {
  fs.mkdirSync(root, { recursive: true });
  fs.writeFileSync(path.join(root, 'key.bin'), randomBytes(16));
  fs.writeFileSync(path.join(root, 'keyinfo.txt'),
    `http://localhost:${port}/key.bin\n${path.join(root, 'key.bin')}\n`);
  execFileSync('ffmpeg', [
    '-hide_banner', '-loglevel', 'error',
    '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=10',
    '-f', 'lavfi', '-i', 'sine=frequency=660:sample_rate=48000',
    '-t', '190', '-c:v', 'libx264', '-preset', 'ultrafast',
    '-profile:v', 'baseline', '-pix_fmt', 'yuv420p', '-g', '60',
    '-c:a', 'aac', '-b:a', '64k', '-metadata:s:a:0', 'language=por',
    '-hls_time', '6', '-hls_playlist_type', 'vod',
    '-hls_key_info_file', path.join(root, 'keyinfo.txt'),
    '-hls_segment_filename', path.join(root, 'segment%03d.ts'),
    path.join(root, 'film.m3u8'),
  ], { stdio: 'inherit', windowsHide: true });
}
const counts = { playlists: 0, segments: 0, keys: 0, rejected: 0 };
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);
  if (url.pathname === '/stats') {
    res.setHeader('Content-Type', 'application/json');
    return res.end(JSON.stringify(counts));
  }
  if (url.pathname === '/provider') {
    res.setHeader('Content-Type', 'text/html');
    return res.end(`<iframe style="width:100%;height:100%" src="http://localhost:${port}/frame"></iframe>`);
  }
  if (url.pathname === '/frame') {
    res.setHeader('Content-Type', 'text/html');
    res.setHeader('Set-Cookie', 'tv_session=fixture; Path=/; HttpOnly; SameSite=None; Secure');
    return res.end(`<video></video><script>
      fetch('/master', {headers: {'X-Session': 'fixture'}}).then(r => r.text());
    </script>`);
  }
  if (!req.headers.cookie?.includes('tv_session=fixture') ||
      req.headers['x-session'] !== 'fixture' ||
      !req.headers.referer?.startsWith(`http://localhost:${port}/frame`)) {
    counts.rejected++;
    res.writeHead(403);
    return res.end('Fixture session missing');
  }
  if (url.pathname === '/master') {
    counts.playlists++;
    res.setHeader('Content-Type', 'text/plain');
    return res.end('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=320x180,CODECS="avc1.42c01e,mp4a.40.2"\n/film.m3u8\n');
  }
  const allowed = /^(film\.m3u8|segment\d+\.ts|key\.bin)$/.test(url.pathname.slice(1));
  if (!allowed) { res.writeHead(404); return res.end(); }
  const file = path.join(root, url.pathname.slice(1));
  if (!fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  if (file.endsWith('.m3u8')) counts.playlists++;
  else if (file.endsWith('.ts')) counts.segments++;
  else counts.keys++;
  res.setHeader('Content-Type', file.endsWith('.m3u8')
    ? 'application/vnd.apple.mpegurl' : file.endsWith('.ts') ? 'video/mp2t' : 'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});
server.listen(port, '127.0.0.1', () => {
  process.stdout.write(`TV HLS fixture ready on port ${port}\n`);
});
