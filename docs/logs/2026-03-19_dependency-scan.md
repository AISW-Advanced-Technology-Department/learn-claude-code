# 依存関係・サプライチェーンセキュリティ調査レポート (2026-03-19)

- 対象リポジトリ: `/home/ushimaru/dc/Copilot/learn-claude-code`
- 調査日時: 2026-03-19
- 対象ファイル: `web/package.json`, `web/package-lock.json`, `requirements.txt`, `web/scripts/extract-content.ts`, `.gitignore`, `web/vercel.json`
- 実施コマンド（抜粋）: `npm audit --package-lock-only --json`, lockfile解析, DNS/TLSヘッダ確認, スクリプト静的確認

## 1) npm依存関係の安全性

- lockfileVersion: `3`
- 総パッケージ数 (package-lock): **235**
- `resolved` 配布元ホスト: **registry.npmjs.org のみ**
- integrity hash: **全235件が `sha512-`、欠損0件、`sha1-` 0件**
- install scriptを持つ依存: `esbuild`, `fsevents`, `sharp`（いずれも広く使われる既知パッケージ）

### 1-1. 直接依存パッケージごとの安全性評価

| 区分 | パッケージ | 指定Version | 評価 |
|---|---|---:|---|
| dependencies | `diff` | `^8.0.3` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `framer-motion` | `^12.34.0` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `lucide-react` | `^0.564.0` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `next` | `16.1.6` | ⚠ npm auditで既知脆弱性あり (GHSA-mq59-m269-xvcx / GHSA-3x4c-7xq6-9pq8 / GHSA-ggv3-7p47-pfv8)。16.2.0以上へ更新推奨。 |
| dependencies | `react` | `19.2.3` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `react-dom` | `19.2.3` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `rehype-highlight` | `^7.0.2` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `rehype-raw` | `^7.0.0` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `rehype-stringify` | `^10.0.1` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `remark-gfm` | `^4.0.1` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `remark-parse` | `^11.0.0` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `remark-rehype` | `^11.1.2` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `tsx` | `^4.21.0` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| dependencies | `unified` | `^11.0.5` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| devDependencies | `@tailwindcss/postcss` | `^4` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| devDependencies | `@types/diff` | `^7.0.2` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| devDependencies | `@types/node` | `^20` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| devDependencies | `@types/react` | `^19` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| devDependencies | `@types/react-dom` | `^19` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| devDependencies | `tailwindcss` | `^4` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |
| devDependencies | `typescript` | `^5` | 重大な異常は検出されず（名称・依存関係とも一般的なエコシステム構成）。 |

### 1-2. npm audit結果（既知脆弱性）

- **[中] next@16.1.6** に既知脆弱性3件（すべて moderate）
  - GHSA-mq59-m269-xvcx: Server ActionsのCSRF回避（null origin）
  - GHSA-3x4c-7xq6-9pq8: next/image キャッシュ無制限増加
  - GHSA-ggv3-7p47-pfv8: rewrite経由のHTTP request smuggling
- 修正可能バージョン: **next 16.2.0**（semver major ではない）

### 1-3. typosquatting / 不自然バージョン観点

- 直接依存・主要推移依存ともに、Next.js/React/remark/rehype/tailwind周辺の一般的構成で、名称上の強いtyposquatting兆候は未検出。
- バージョンは全体に新しめ（React 19 / Next 16 / Tailwind 4 系）で、異常に古い固定依存は目立たない。

### 1-4. 全依存パッケージ一覧（package-lock.json由来）

- `@alloc/quick-lru@5.2.0`
- `@emnapi/runtime@1.8.1`
- `@esbuild/aix-ppc64@0.27.3`
- `@esbuild/android-arm@0.27.3`
- `@esbuild/android-arm64@0.27.3`
- `@esbuild/android-x64@0.27.3`
- `@esbuild/darwin-arm64@0.27.3`
- `@esbuild/darwin-x64@0.27.3`
- `@esbuild/freebsd-arm64@0.27.3`
- `@esbuild/freebsd-x64@0.27.3`
- `@esbuild/linux-arm@0.27.3`
- `@esbuild/linux-arm64@0.27.3`
- `@esbuild/linux-ia32@0.27.3`
- `@esbuild/linux-loong64@0.27.3`
- `@esbuild/linux-mips64el@0.27.3`
- `@esbuild/linux-ppc64@0.27.3`
- `@esbuild/linux-riscv64@0.27.3`
- `@esbuild/linux-s390x@0.27.3`
- `@esbuild/linux-x64@0.27.3`
- `@esbuild/netbsd-arm64@0.27.3`
- `@esbuild/netbsd-x64@0.27.3`
- `@esbuild/openbsd-arm64@0.27.3`
- `@esbuild/openbsd-x64@0.27.3`
- `@esbuild/openharmony-arm64@0.27.3`
- `@esbuild/sunos-x64@0.27.3`
- `@esbuild/win32-arm64@0.27.3`
- `@esbuild/win32-ia32@0.27.3`
- `@esbuild/win32-x64@0.27.3`
- `@img/colour@1.0.0`
- `@img/sharp-darwin-arm64@0.34.5`
- `@img/sharp-darwin-x64@0.34.5`
- `@img/sharp-libvips-darwin-arm64@1.2.4`
- `@img/sharp-libvips-darwin-x64@1.2.4`
- `@img/sharp-libvips-linux-arm@1.2.4`
- `@img/sharp-libvips-linux-arm64@1.2.4`
- `@img/sharp-libvips-linux-ppc64@1.2.4`
- `@img/sharp-libvips-linux-riscv64@1.2.4`
- `@img/sharp-libvips-linux-s390x@1.2.4`
- `@img/sharp-libvips-linux-x64@1.2.4`
- `@img/sharp-libvips-linuxmusl-arm64@1.2.4`
- `@img/sharp-libvips-linuxmusl-x64@1.2.4`
- `@img/sharp-linux-arm@0.34.5`
- `@img/sharp-linux-arm64@0.34.5`
- `@img/sharp-linux-ppc64@0.34.5`
- `@img/sharp-linux-riscv64@0.34.5`
- `@img/sharp-linux-s390x@0.34.5`
- `@img/sharp-linux-x64@0.34.5`
- `@img/sharp-linuxmusl-arm64@0.34.5`
- `@img/sharp-linuxmusl-x64@0.34.5`
- `@img/sharp-wasm32@0.34.5`
- `@img/sharp-win32-arm64@0.34.5`
- `@img/sharp-win32-ia32@0.34.5`
- `@img/sharp-win32-x64@0.34.5`
- `@jridgewell/gen-mapping@0.3.13`
- `@jridgewell/remapping@2.3.5`
- `@jridgewell/resolve-uri@3.1.2`
- `@jridgewell/sourcemap-codec@1.5.5`
- `@jridgewell/trace-mapping@0.3.31`
- `@next/env@16.1.6`
- `@next/swc-darwin-arm64@16.1.6`
- `@next/swc-darwin-x64@16.1.6`
- `@next/swc-linux-arm64-gnu@16.1.6`
- `@next/swc-linux-arm64-musl@16.1.6`
- `@next/swc-linux-x64-gnu@16.1.6`
- `@next/swc-linux-x64-musl@16.1.6`
- `@next/swc-win32-arm64-msvc@16.1.6`
- `@next/swc-win32-x64-msvc@16.1.6`
- `@swc/helpers@0.5.15`
- `@tailwindcss/node@4.1.18`
- `@tailwindcss/oxide@4.1.18`
- `@tailwindcss/oxide-android-arm64@4.1.18`
- `@tailwindcss/oxide-darwin-arm64@4.1.18`
- `@tailwindcss/oxide-darwin-x64@4.1.18`
- `@tailwindcss/oxide-freebsd-x64@4.1.18`
- `@tailwindcss/oxide-linux-arm-gnueabihf@4.1.18`
- `@tailwindcss/oxide-linux-arm64-gnu@4.1.18`
- `@tailwindcss/oxide-linux-arm64-musl@4.1.18`
- `@tailwindcss/oxide-linux-x64-gnu@4.1.18`
- `@tailwindcss/oxide-linux-x64-musl@4.1.18`
- `@tailwindcss/oxide-wasm32-wasi@4.1.18`
- `@tailwindcss/oxide-win32-arm64-msvc@4.1.18`
- `@tailwindcss/oxide-win32-x64-msvc@4.1.18`
- `@tailwindcss/postcss@4.1.18`
- `@types/debug@4.1.12`
- `@types/diff@7.0.2`
- `@types/hast@3.0.4`
- `@types/mdast@4.0.4`
- `@types/ms@2.1.0`
- `@types/node@20.19.33`
- `@types/react@19.2.14`
- `@types/react-dom@19.2.3`
- `@types/unist@3.0.3`
- `@ungap/structured-clone@1.3.0`
- `bail@2.0.2`
- `baseline-browser-mapping@2.9.19`
- `caniuse-lite@1.0.30001770`
- `ccount@2.0.1`
- `character-entities@2.0.2`
- `character-entities-html4@2.1.0`
- `character-entities-legacy@3.0.0`
- `client-only@0.0.1`
- `comma-separated-tokens@2.0.3`
- `csstype@3.2.3`
- `debug@4.4.3`
- `decode-named-character-reference@1.3.0`
- `dequal@2.0.3`
- `detect-libc@2.1.2`
- `devlop@1.1.0`
- `diff@8.0.3`
- `enhanced-resolve@5.19.0`
- `entities@6.0.1`
- `esbuild@0.27.3`
- `escape-string-regexp@5.0.0`
- `extend@3.0.2`
- `framer-motion@12.34.0`
- `fsevents@2.3.3`
- `get-tsconfig@4.13.6`
- `graceful-fs@4.2.11`
- `hast-util-from-parse5@8.0.3`
- `hast-util-is-element@3.0.0`
- `hast-util-parse-selector@4.0.0`
- `hast-util-raw@9.1.0`
- `hast-util-to-html@9.0.5`
- `hast-util-to-parse5@8.0.1`
- `hast-util-to-text@4.0.2`
- `hast-util-whitespace@3.0.0`
- `hastscript@9.0.1`
- `highlight.js@11.11.1`
- `html-void-elements@3.0.0`
- `is-plain-obj@4.1.0`
- `jiti@2.6.1`
- `lightningcss@1.30.2`
- `lightningcss-android-arm64@1.30.2`
- `lightningcss-darwin-arm64@1.30.2`
- `lightningcss-darwin-x64@1.30.2`
- `lightningcss-freebsd-x64@1.30.2`
- `lightningcss-linux-arm-gnueabihf@1.30.2`
- `lightningcss-linux-arm64-gnu@1.30.2`
- `lightningcss-linux-arm64-musl@1.30.2`
- `lightningcss-linux-x64-gnu@1.30.2`
- `lightningcss-linux-x64-musl@1.30.2`
- `lightningcss-win32-arm64-msvc@1.30.2`
- `lightningcss-win32-x64-msvc@1.30.2`
- `longest-streak@3.1.0`
- `lowlight@3.3.0`
- `lucide-react@0.564.0`
- `magic-string@0.30.21`
- `markdown-table@3.0.4`
- `mdast-util-find-and-replace@3.0.2`
- `mdast-util-from-markdown@2.0.2`
- `mdast-util-gfm@3.1.0`
- `mdast-util-gfm-autolink-literal@2.0.1`
- `mdast-util-gfm-footnote@2.1.0`
- `mdast-util-gfm-strikethrough@2.0.0`
- `mdast-util-gfm-table@2.0.0`
- `mdast-util-gfm-task-list-item@2.0.0`
- `mdast-util-phrasing@4.1.0`
- `mdast-util-to-hast@13.2.1`
- `mdast-util-to-markdown@2.1.2`
- `mdast-util-to-string@4.0.0`
- `micromark@4.0.2`
- `micromark-core-commonmark@2.0.3`
- `micromark-extension-gfm@3.0.0`
- `micromark-extension-gfm-autolink-literal@2.1.0`
- `micromark-extension-gfm-footnote@2.1.0`
- `micromark-extension-gfm-strikethrough@2.1.0`
- `micromark-extension-gfm-table@2.1.1`
- `micromark-extension-gfm-tagfilter@2.0.0`
- `micromark-extension-gfm-task-list-item@2.1.0`
- `micromark-factory-destination@2.0.1`
- `micromark-factory-label@2.0.1`
- `micromark-factory-space@2.0.1`
- `micromark-factory-title@2.0.1`
- `micromark-factory-whitespace@2.0.1`
- `micromark-util-character@2.1.1`
- `micromark-util-chunked@2.0.1`
- `micromark-util-classify-character@2.0.1`
- `micromark-util-combine-extensions@2.0.1`
- `micromark-util-decode-numeric-character-reference@2.0.2`
- `micromark-util-decode-string@2.0.1`
- `micromark-util-encode@2.0.1`
- `micromark-util-html-tag-name@2.0.1`
- `micromark-util-normalize-identifier@2.0.1`
- `micromark-util-resolve-all@2.0.1`
- `micromark-util-sanitize-uri@2.0.1`
- `micromark-util-subtokenize@2.1.0`
- `micromark-util-symbol@2.0.1`
- `micromark-util-types@2.0.2`
- `motion-dom@12.34.0`
- `motion-utils@12.29.2`
- `ms@2.1.3`
- `nanoid@3.3.11`
- `next@16.1.6`
- `next/node_modules/postcss@8.4.31`
- `parse5@7.3.0`
- `picocolors@1.1.1`
- `postcss@8.5.6`
- `property-information@7.1.0`
- `react@19.2.3`
- `react-dom@19.2.3`
- `rehype-highlight@7.0.2`
- `rehype-raw@7.0.0`
- `rehype-stringify@10.0.1`
- `remark-gfm@4.0.1`
- `remark-parse@11.0.0`
- `remark-rehype@11.1.2`
- `remark-stringify@11.0.0`
- `resolve-pkg-maps@1.0.0`
- `scheduler@0.27.0`
- `semver@7.7.4`
- `sharp@0.34.5`
- `source-map-js@1.2.1`
- `space-separated-tokens@2.0.2`
- `stringify-entities@4.0.4`
- `styled-jsx@5.1.6`
- `tailwindcss@4.1.18`
- `tapable@2.3.0`
- `trim-lines@3.0.1`
- `trough@2.2.0`
- `tslib@2.8.1`
- `tsx@4.21.0`
- `typescript@5.9.3`
- `undici-types@6.21.0`
- `unified@11.0.5`
- `unist-util-find-after@5.0.0`
- `unist-util-is@6.0.1`
- `unist-util-position@5.0.0`
- `unist-util-stringify-position@4.0.0`
- `unist-util-visit@5.1.0`
- `unist-util-visit-parents@6.0.2`
- `vfile@6.0.3`
- `vfile-location@5.0.3`
- `vfile-message@4.0.3`
- `web-namespaces@2.0.1`
- `zwitch@2.0.4`

## 2) Python依存関係（requirements.txt）

- `anthropic>=0.25.0`
- `python-dotenv>=1.0.0`

評価:
- `anthropic>=0.25.0`: 主要DB上で「パッケージ本体への重大既知CVE」は限定的。
- `python-dotenv>=1.0.0`: 主要脆弱性DB上で重大既知脆弱性は確認されず。
- ただし本環境では `pip-audit` 実行基盤不足（venv/ensurepip制約）により、ローカルでの機械的照合は未完。外部脆弱性情報で補完。

## 3) スクリプトの安全性

- `web/package.json` scripts: `extract`, `predev`, `dev`, `prebuild`, `build`, `start`
- lifecycle hooks確認: **preinstall/install/postinstall/prepare 系は未定義**
- `predev`/`prebuild` は `npm run extract` を実行。
- `web/scripts/extract-content.ts` はローカルファイル走査・JSON生成が中心で、`child_process` や外部ダウンロード実行は未検出。
- 直接の危険コマンド（`curl|wget|bash -c|eval|rm -rf`）は scripts配下で未検出。

## 4) 設定・インフラファイル

### 4-1. .gitignore
- ルート `.gitignore` は Python/Node/Next/Vercel/.env など主要秘匿・生成物を適切に除外。
- `web/.gitignore` も node_modules, .next, .env*, .vercel 等を除外しており概ね適切。

### 4-2. vercel.json リダイレクト
- 条件: Host が `learn-claude-agents.vercel.app` のとき `https://learn.shareai.run/:path` に恒久リダイレクト。
- 宛先ドメイン `learn.shareai.run` は DNS解決・HTTPS応答(200)・有効証明書を確認。
- 一方、`learn-claude-agents.vercel.app` への HTTPS ヘッダ取得は接続リセットが発生（環境要因/配信設定要確認）。
- セキュリティ観点では、外部ドメインへ全面転送する設計のため、ドメイン所有権・運用体制・HSTS/CSPの継続監視を推奨。

## 検出された問題（重要度付き）

1. **[中]** `next@16.1.6` の既知脆弱性3件（npm audit検出）
2. **[低]** Python依存の機械監査（pip-audit）が環境制約で未実施
3. **[低]** `vercel.app` 側ホストのHTTPS応答が取得できず、リダイレクト元健全性の実地確認が不完全

## 推奨対応

1. `web` で `next` を **16.2.0 以上**へ更新し、`npm audit --package-lock-only` を再実行。
2. CIに `npm audit --audit-level=moderate` と lockfile改変監視（integrity差分検出）を追加。
3. Python側は CI で `pip-audit -r requirements.txt` を実行可能な環境を整備。
4. `learn.shareai.run` のドメイン所有権/証明書更新監視（失効通知）を設定。
5. バイナリ依存（`esbuild`/`sharp`）に対しては lockfile固定・CI再現ビルド・SBOM出力を導入。

## 総合評価

**総合: B-（中程度の是正が必要）**

- lockfile整合性・配布元一元化・スクリプト安全性は良好。
- 主な懸念は `next` の既知脆弱性で、アップデートにより短期解消可能。
- Python監査自動化とリダイレクト先運用監視を追加すれば、サプライチェーン耐性はさらに向上。
