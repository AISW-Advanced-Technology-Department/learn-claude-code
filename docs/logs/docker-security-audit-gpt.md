# Dockerデプロイ設定 セキュリティ監査レポート

対象:
- `deploy/Dockerfile`
- `deploy/docker-compose.yml`
- `deploy/start.sh`
- `deploy/nginx.conf`
- `.dockerignore`

前提:
- Next.js static export を nginx で配信
- 社内イントラ用途（8314）
- Basic認証は環境変数から動的生成
- `read_only` + 非root実行

---

## 1. Dockerfile Multi-stage Build
**Status**: ⚠️ 軽微な問題

### Findings
- **マルチステージ自体は適切**。最終イメージにはビルド成果物のみをコピーしており、ビルドツール一式は持ち込まれていない（`deploy/Dockerfile:18`）。
- Builderで `COPY . .` を実行しており、ビルドコンテキスト全体がbuilderレイヤに入る（`deploy/Dockerfile:4`）。
  - 最終イメージへの漏洩は起きにくいが、**ビルド時の露出面積が広い**（不要ファイル混入、キャッシュ汚染、誤配置ファイルの取り込みリスク）。
- `.dockerignore` は主要な除外（`.git`, `.env`, `node_modules` 等）を実施しており一定の緩和になっている（`.dockerignore:1-14`）。
- レイヤ最適化は改善余地あり。`COPY . .` の後に `npm ci` のため、ソース変更で依存インストールキャッシュが失効しやすい（`deploy/Dockerfile:4,7`）。
- ベースイメージが mutable tag (`node:22-alpine`, `nginx:alpine`) で固定度が弱い（`deploy/Dockerfile:1,9`）。サプライチェーン観点で再現性・検証性が不足。

### Recommendations
1. **builderのCOPYを最小化**（`web`配下中心に限定）
```dockerfile
FROM node:22.12-alpine3.20@sha256:<digest> AS builder
WORKDIR /repo/web

COPY web/package*.json ./
RUN npm ci

COPY web/ ./
RUN npm run build
```

2. **ランタイムイメージをdigest pinning**
```dockerfile
FROM nginx:1.27.3-alpine3.20@sha256:<digest>
```

3. **不要コンテキストをさらに削減**（後述 `.dockerignore` も強化）

---

## 2. docker-compose.yml Security
**Status**: ⚠️ 軽微な問題

### Findings
- `read_only: true` は適切（`deploy/docker-compose.yml:12`）。
- `tmpfs` で `/tmp`, `/var/cache/nginx`, `/run` を確保しており、nginx動作に必要な書き込み先を概ねカバー（`deploy/docker-compose.yml:13-16`）。
  - `nginx.conf` 側で pid/temp を `/tmp` に寄せており整合性あり（`deploy/nginx.conf:2,11-15`）。
- `no-new-privileges:true` と `cap_drop: [ALL]` は強いハードニングとして妥当（`deploy/docker-compose.yml:17-20`）。
- Basic認証情報を平文環境変数で受ける設計（`deploy/docker-compose.yml:8-10`）は、`docker inspect` 等からの露出リスクが残る。
- 追加可能な防御設定が未定義:
  - `healthcheck` なし
  - `pids_limit` / `mem_limit` / `cpus` などのリソース制限なし
  - `logging` ローテーション制限なし
  - ネットワーク制限（専用network、`internal`活用等）なし

### Recommendations
```yaml
services:
  web:
    read_only: true
    tmpfs:
      - /tmp:size=16m,noexec,nosuid,nodev
      - /run:size=8m,noexec,nosuid,nodev
      - /var/cache/nginx:size=32m,noexec,nosuid,nodev
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    pids_limit: 100
    mem_limit: 256m
    cpus: "1.0"
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

環境変数の代替（推奨）:
- `BASIC_AUTH_PASS_FILE` + secret mount
- もしくは Docker secrets / 外部secret管理

---

## 3. .dockerignore
**Status**: ⚠️ 軽微な問題

### Findings
- 主要機密・不要物は除外済み（`.git`, `.github`, `.env`, `node_modules`, `.next`, `out` など）（`.dockerignore:1-14`）。
- ただし、一般的な秘密情報パターンの除外が不足する可能性:
  - `*.pem`, `*.key`, `*.crt`, `secrets/`, `.aws/`, `.npmrc`, `.ssh/` など
- ビルドに不要な文書群（`docs/`, `skills/` など）がコンテキストへ入る可能性があり、漏洩面とビルド転送量を増やす。

### Recommendations
```dockerignore
# 既存に加えて推奨
**/*.pem
**/*.key
**/*.crt
**/*.p12
**/*.pfx
**/secrets/
.aws/
.ssh/
.npmrc
.vscode/
.docs/
docs/
skills/
```

※ `docs/` や `skills/` はビルドで不要な場合のみ除外（必要物があるなら個別精査）。

---

## 4. Non-root User Execution
**Status**: ✅ 問題なし

### Findings
- `USER nginx` が設定されており、非root実行になっている（`deploy/Dockerfile:22`）。
- 必要ディレクトリに対して事前作成・所有権付与あり（`deploy/Dockerfile:13-14`）。
- `read_only` 環境での書き込み先は `tmpfs` に寄せられている（`deploy/docker-compose.yml:13-16`、`deploy/nginx.conf:2,11-15`、`deploy/start.sh:17`）。
- `start.sh` は `/tmp/.htpasswd` を生成し、nginx設定の `auth_basic_user_file /tmp/.htpasswd;` と一致（`deploy/start.sh:17-18`, `deploy/nginx.conf:41`）。

### Recommendations
- 現状設計は整合しているため大きな修正不要。
- 追加強化として `tmpfs` に `nosuid,nodev,noexec` オプション付与を推奨（2章参照）。

---

## 5. Build Logic Verification
**Status**: ✅ 問題なし（運用上の改善余地あり）

### Findings
- `docker-compose.yml` の build context は `..`、dockerfile は `deploy/Dockerfile` 指定で、`COPY . .` はリポジトリルート全体を `/repo` に取り込む構成として論理整合（`deploy/docker-compose.yml:3-5`, `deploy/Dockerfile:3-4`）。
- Builder成果物 ` /repo/web/out/ ` を runtimeへコピーする流れは Next.js static export 前提として妥当（`deploy/Dockerfile:18`）。
- `start.sh` は `set -eu`、入力値チェック、nginx foreground起動があり基本動作は堅牢（`deploy/start.sh:2-20`）。
- `read_only + non-root` 条件下でも `.htpasswd` 書き込み先が `/tmp` のため動作整合（`deploy/start.sh:17`, `deploy/docker-compose.yml:14`）。

### Recommendations
- 将来のビルド失敗を防ぐため、`web/package-lock.json` の存在をCIで保証。
- `COPY . .` の縮小で再現性・速度・露出面を改善（1章参照）。
- 可能であれば Compose に `healthcheck` を追加し、起動成功判定を明示化（2章参照）。

---

## 総評
現構成は **read-only rootfs / non-root / capability削減 / no-new-privileges** が揃っており、Dockerハードニングとしては良好です。重大な脆弱性は見当たりません。

一方で、実運用のセキュリティ成熟度を上げるには以下3点が優先です。
1. **ベースイメージのdigest固定**（供給網リスク低減）
2. **build context最小化**（`COPY . .`見直し + `.dockerignore`強化）
3. **Composeの運用防御追加**（healthcheck / resource制限 / logging制限 / secrets化）

これらを反映すれば、イントラ用途として一段高い堅牢性に到達できます。
