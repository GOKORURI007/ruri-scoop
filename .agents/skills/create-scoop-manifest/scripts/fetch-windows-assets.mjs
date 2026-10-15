#!/usr/bin/env node
// 从 GitHub Release API 拿 Windows 资源的版本号、URL 和 sha256——不下安装包。
//
// 用法:
//   node fetch-windows-assets.mjs <owner>/<repo> [tag]
//
// 示例:
//   node fetch-windows-assets.mjs liliMozi/openhanako
//   node fetch-windows-assets.mjs liliMozi/openhanako v0.450.0
//
// 输出:tag、剥掉 v 的版本号、每个 Windows 资源的名字/URL/大小/sha256
//       其中 sha256 直接对应 Scoop manifest 里的 `hash` 字段。

const [repo, tag = 'latest'] = process.argv.slice(2);
if (!repo || !/^[^/\s]+\/[^/\s]+$/.test(repo)) {
  console.error('用法: node fetch-windows-assets.mjs <owner>/<repo> [tag]');
  process.exit(1);
}

const url =
  tag === 'latest'
    ? `https://api.github.com/repos/${repo}/releases/latest`
    : `https://api.github.com/repos/${repo}/releases/tags/${tag}`;

const res = await fetch(url, {
  headers: { 'User-Agent': 'create-scoop-manifest-skill' },
});
if (!res.ok) {
  console.error(`HTTP ${res.status} 请求 ${url} 失败`);
  console.error(await res.text());
  process.exit(1);
}

const release = await res.json();
const version = (release.tag_name ?? '').replace(/^v/, '');

console.log(`Tag: ${release.tag_name}`);
console.log(`Version: ${version}`);
console.log(`Published: ${release.published_at}`);
console.log('');

const winRe = /windows[-_].*\.(exe|zip|msi|7z)$/i;
let printed = 0;
for (const asset of release.assets ?? []) {
  if (!winRe.test(asset.name)) continue;
  const sha = (asset.digest ?? '').replace(/^sha256:/, '');
  console.log(`Asset: ${asset.name}`);
  console.log(`  url:    ${asset.browser_download_url}`);
  console.log(`  size:   ${asset.size} bytes`);
  console.log(`  sha256: ${sha}`);
  console.log('');
  printed += 1;
}

if (printed === 0) {
  console.error('没有匹配到 Windows 资源。列出所有 asset 供检查:');
  for (const asset of release.assets ?? []) {
    console.error(`  - ${asset.name}`);
  }
  process.exit(2);
}