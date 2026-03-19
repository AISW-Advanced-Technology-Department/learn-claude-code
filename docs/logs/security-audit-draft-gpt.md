# deploy インフラセキュリティ監査レポート（Docker / nginx）

監査対象:
- `deploy/Dockerfile`
- `deploy/nginx.conf`
- `deploy/docker-compose.yml`
- `deploy/start.sh`
- `.dockerignore`

前提:
- Next.js static export を nginx で配信
- 社内イントラ向け（`8314`）
- Basic認証は環境変数から起動時生成
- `read_only: true` / 非root実行
- **CSP の sha256 ハッシュは正しいことが事前検証済み（本監査でも問題として扱わない）**

---

## 1) 総評（エグゼクティブサマリ）

全体として、**非root実行・capability削除・read-only FS・no-new-privileges** といったコンテナハードニングの重要施策は実装済みで、基礎防御は良好です。

一方で、運用時の実害につながりやすい論点として以下が残っています。

1. **ベースイメージのdigest未固定**（サプライチェーン変動リスク）
2. **`COPY . .` + `.dockerignore`の除外不足**（ビルドコンテキストへの機微ファイル混入）
3. **Basic認証の平文パスワードが環境変数/プロセス引数経由で露出し得る設計**
4. **Compose側のリソース上限・ヘルスチェック・ログ制御不足**（可用性/監査性）
5. **nginxのレート制限未実装**（Basic認証に対する総当たり耐性）

---

## 2) `deploy/Dockerfile` 監査

### D-01 ベースイメージがタグ指定のみ（digest未固定）
- **Severity: Medium**
- **内容**: `node:22-alpine` と `nginx:alpine` はタグ参照であり、将来同タグが別digestへ差し替わると、ビルド結果が非決定化し、既知脆弱性の再混入や予期しない挙動変更が起こり得ます。
- **修正案（具体）**:
  ```dockerfile
  FROM node:22-alpine@sha256:<digest> AS builder
  ...
  FROM nginx:alpine@sha256:<digest>
  ```
  - 可能なら `nginx:1.27-alpine@sha256:...` のように**バージョン+digest**固定を推奨。

### D-02 `COPY . .` によるビルドコンテキスト過大化・機微混入面積
- **Severity: Medium**
- **内容**: builder段で `COPY . .` を実施しており、`.dockerignore`で漏れたファイルがそのままコンテキストに入ります。現状 `.dockerignore` は一定配慮されていますが、秘密鍵系の除外が不足しているため、誤配置ファイルの混入余地があります。
- **修正案（具体）**:
  - Dockerfileを選択コピーへ変更（キャッシュ効率・漏えい面積とも改善）:
    ```dockerfile
    WORKDIR /repo/web
    COPY web/package*.json ./
    RUN npm ci
    COPY web/ ./
    RUN npm run build
    ```
  - ルート全体をコピーする構成を避ける。

### D-03 マルチステージ化自体は適切
- **Severity: OK**
- **内容**: 最終イメージに `/repo/web/out` のみコピーしており、Node実行環境やビルド依存をランタイムへ持ち込んでいません。攻撃面積縮小として良い実装です。
- **修正案**: なし（現状維持推奨）

### D-04 `openssl` 追加によるランタイム攻撃面積増加
- **Severity: Low**
- **内容**: `apk add openssl` は起動時ハッシュ生成のため必要ですが、ランタイムパッケージを1つ増やす分だけ脆弱性対象面積は増えます。
- **修正案（具体）**:
  - 可能なら `htpasswd` 生成をビルド/エントリポイント別実装に分離するか、軽量な代替手段を検討。
  - 現行要件上必要なら許容し、**定期的なイメージ脆弱性スキャン**を必須化。

### D-05 非root実行は正しく構成
- **Severity: OK**
- **内容**: `USER nginx` を明示し、必要ディレクトリ所有権も付与済み。`read_only` + `tmpfs` 構成と整合しています。
- **修正案**: なし

### D-06 キャッシュ効率（セキュリティ運用上の更新速度）
- **Severity: Info**
- **内容**: `COPY . .` 後に `npm ci` しているため、少しの変更で依存レイヤが無効化され、再ビルド時間増→脆弱性修正展開の遅延につながる可能性があります。
- **修正案**: D-02の選択コピーに統合。

---

## 3) `deploy/nginx.conf` 監査

### N-01 セキュリティヘッダ群は概ね良好
- **Severity: OK**
- **内容**: `CSP`（ハッシュ含む）、`X-Content-Type-Options`、`X-Frame-Options`、`Referrer-Policy`、`Permissions-Policy` を `always` で配信しており、防御層として適切です。
- **修正案**: なし

### N-02 HSTS 未設定
- **Severity: Low**
- **内容**: `Strict-Transport-Security` がありません。HTTPS終端が別レイヤの場合はそちらで設定すべきですが、外部公開やTLS終端が本nginxの場合は中間者対策が不足します。
- **修正案（具体）**:
  - TLS配信が確実な経路でのみ:
    ```nginx
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    ```
  - 既にLB/IngressでTLS終端しているなら、その層でHSTSを設定。

### N-03 Basic認証防御としてレート制限未実装
- **Severity: Medium**
- **内容**: `auth_basic` はあるものの、`limit_req`/`limit_conn` が無いため、総当たり試行に対する抑止が弱いです。
- **修正案（具体）**:
  ```nginx
  http {
      limit_req_zone $binary_remote_addr zone=auth_zone:10m rate=5r/m;
      limit_conn_zone $binary_remote_addr zone=conn_zone:10m;
      server {
          location / {
              limit_req zone=auth_zone burst=10 nodelay;
              limit_conn conn_zone 20;
              try_files $uri $uri/ /index.html;
          }
      }
  }
  ```

### N-04 アクセスログ/エラーログ出力先の明示不足
- **Severity: Medium**
- **内容**: ログ設定を明示していないため、監査証跡の担保が設定依存になります。`read_only`運用では書込先不整合も起こり得ます。
- **修正案（具体）**:
  ```nginx
  error_log /dev/stderr warn;
  access_log /dev/stdout;
  ```
  - コンテナ標準出力へ集約し、集中ログ基盤へ転送。

### N-05 gzip有効化に伴うBREACH観点
- **Severity: Low**
- **内容**: BREACHは「TLS + 圧縮 + 応答本文に秘密が反映」の条件で問題化します。本構成は静的サイト中心で、秘密反映の動的応答は限定的なためリスクは高くありません。
- **修正案（具体）**:
  - 現状許容可能。
  - 将来、秘密値を本文に反映する機能を追加する場合は、そのロケーションで `gzip off;` を適用。

### N-06 HTTPメソッド制限は妥当
- **Severity: OK**
- **内容**: `GET/HEAD` のみに制限し、他メソッドを `405` で拒否。静的配信用途として適切です。
- **修正案**: なし

### N-07 `client_max_body_size` 未明示
- **Severity: Info**
- **内容**: 本構成はGET/HEAD限定で高リスクではありませんが、将来的な設定変更時に過大ボディ受信を防ぐ保険として明示推奨です。
- **修正案（具体）**:
  ```nginx
  client_max_body_size 1m;
  ```

---

## 4) `deploy/docker-compose.yml` 監査

### C-01 ポート公開が全IFバインド
- **Severity: Medium**
- **内容**: `"8314:8080"` は全インターフェース公開です。イントラ用途でも意図しないセグメントから到達可能になる場合があります。
- **修正案（具体）**:
  - ローカル限定なら:
    ```yaml
    ports:
      - "127.0.0.1:8314:8080"
    ```
  - それ以外はFW/SGで到達元を厳格制限。

### C-02 リソース制限（メモリ/CPU/PID）未設定
- **Severity: Medium**
- **内容**: DoS耐性とノイジーネイバー抑制の観点で、上限が無いのは運用リスクです。
- **修正案（具体）**:
  ```yaml
  services:
    web:
      mem_limit: 256m
      cpus: "0.50"
      pids_limit: 100
    
  ```
  - 値は実測に合わせて調整。

### C-03 healthcheck 未設定
- **Severity: Medium**
- **内容**: プロセス生存だけではサービス健全性を判定できません。認証設定不備やnginx起動失敗の自動検知が弱いです。
- **修正案（具体）**:
  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8080/ || exit 1"]
    interval: 30s
    timeout: 5s
    retries: 3
    start_period: 10s
  ```

### C-04 ログローテーション設定未指定
- **Severity: Low**
- **内容**: `json-file` デフォルト運用ではログ肥大化リスクがあります。
- **修正案（具体）**:
  ```yaml
  logging:
    driver: json-file
    options:
      max-size: "10m"
      max-file: "3"
  ```

### C-05 環境変数での認証情報注入
- **Severity: Medium**
- **内容**: `BASIC_AUTH_PASS` は `docker inspect` 等で閲覧され得る運用面リスクがあります（ホスト権限者前提でも漏えい面が増える）。
- **修正案（具体）**:
  - Compose secrets（ファイルマウント）へ移行し、`start.sh` 側は `*_FILE` 読み込み対応。

### C-06 read_only / tmpfs / no-new-privileges / cap_drop は良好
- **Severity: OK**
- **内容**: 代表的なコンテナ逸脱対策が適切に実装されています。
- **修正案**: なし

---

## 5) `deploy/start.sh` 監査

### S-01 `sh` スクリプトで `$'\n'` / `$'\r'` を使用（POSIX非依存挙動）
- **Severity: Medium**
- **内容**: `#!/bin/sh` なのに `case` で ANSI-C quoting (`$'...'`) を利用。実装依存で解釈差が出ると改行拒否ロジックが機能しない可能性があります。
- **修正案（具体）**:
  - POSIX互換の検証に置換:
    ```sh
    case "$BASIC_AUTH_USER" in
      *:*) echo "invalid" >&2; exit 1;;
    esac
    printf '%s' "$BASIC_AUTH_USER" | grep -q '[\r\n]' && { echo "invalid" >&2; exit 1; }
    ```

### S-02 `openssl passwd -apr1 "${BASIC_AUTH_PASS}"` の引数露出
- **Severity: Medium**
- **内容**: パスワードをコマンド引数に渡すと、短時間ながらプロセス一覧から観測される可能性があります（同一ホスト権限者・同名前空間前提）。
- **修正案（具体）**:
  ```sh
  HASHED_PASS="$(printf '%s' "$BASIC_AUTH_PASS" | openssl passwd -apr1 -stdin)"
  ```
  - 併せて環境変数方式自体を secrets ファイル方式へ移行推奨。

### S-03 `.htpasswd` 作成前 `umask` 未設定
- **Severity: Low**
- **内容**: 直後に `chmod 600` しているため最終権限は適切ですが、生成瞬間のデフォルト権限を厳格化するのが安全です。
- **修正案（具体）**:
  ```sh
  umask 077
  printf '%s:%s\n' "$BASIC_AUTH_USER" "$HASHED_PASS" > /tmp/.htpasswd
  ```

### S-04 コマンドインジェクション耐性は概ね良好
- **Severity: OK**
- **内容**: 変数展開は適切にダブルクォートされており、`exec nginx -g "daemon off;"` も固定文字列で安全です。
- **修正案**: なし

### S-05 ハッシュ方式 `apr1` の強度
- **Severity: Low**
- **内容**: Apache MD5 (`apr1`) は現代基準では強くありません。Basic認証用途としては可用ですが、より強い方式が望ましいです。
- **修正案（具体）**:
  - 互換性確認の上 `bcrypt` (`htpasswd -B`) 等を検討。

---

## 6) `.dockerignore` 監査

### G-01 主要不要物の除外は良好
- **Severity: OK**
- **内容**: `.git`、`node_modules`、`out`、`.env*` など、典型的なノイズ/機微の一部は除外済みです。
- **修正案**: なし

### G-02 秘密鍵・証明書系の除外不足
- **Severity: Medium**
- **内容**: `*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `*.p12`, `*.jks` 等の一般的な秘密素材が未除外。誤配置時にビルドコンテキストへ混入し得ます。
- **修正案（具体）**:
  ```dockerignore
  **/*.pem
  **/*.key
  **/*.crt
  **/*.p12
  **/*.pfx
  **/*.jks
  **/id_rsa
  **/id_rsa.pub
  **/id_ed25519
  **/id_ed25519.pub
  ```

### G-03 Dockerfile除外の要否
- **Severity: Info**
- **内容**: `deploy/Dockerfile` はビルドに必要なため、除外は不要です。ここは問題ではありません。
- **修正案**: なし

---

## 7) 横断評価（Non-root / Build / Runtime）

### X-01 非root実行の整合性
- **Severity: OK**
- **評価**:
  - Dockerfile: `USER nginx`
  - nginx.conf: `pid /tmp/nginx.pid` など書込先を `/tmp` に寄せている
  - compose: `read_only: true` + `tmpfs` 指定
- **所見**: 非root + 読み取り専用FS運用として整合が取れており、良い設計です。

### X-02 Buildロジック最適化余地
- **Severity: Medium**
- **内容**: `COPY . .` によりキャッシュ効率と最小権限原則（不要ファイル非持込）が悪化。セキュリティ修正版の高速デリバリにも影響します。
- **修正案**: Dockerfileの選択コピー + `.dockerignore` 強化をセットで実施。

---

## 8) 優先対応順（推奨）

1. **最優先**: イメージdigest固定（D-01）
2. **最優先**: `start.sh` の引数渡し廃止（S-02）+ POSIX互換修正（S-01）
3. **高**: `.dockerignore` に秘密素材除外追加（G-02）+ Dockerfile選択コピー化（D-02）
4. **高**: nginxレート制限追加（N-03）
5. **中**: Composeの `mem_limit/cpus/pids_limit`、`healthcheck`、`logging` 追加（C-02/C-03/C-04）
6. **条件付き**: HSTS適用箇所の明確化（N-02）

---

## 9) 参考修正スニペット（最小セット）

### Dockerfile（抜粋）
```dockerfile
FROM node:22-alpine@sha256:<digest> AS builder
WORKDIR /repo/web
COPY web/package*.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

FROM nginx:1.27-alpine@sha256:<digest>
...
```

### start.sh（抜粋）
```sh
#!/bin/sh
set -eu
umask 077

case "$BASIC_AUTH_USER" in
  *:*) echo "BASIC_AUTH_USER contains invalid characters." >&2; exit 1 ;;
esac
printf '%s' "$BASIC_AUTH_USER" | grep -q '[\r\n]' && {
  echo "BASIC_AUTH_USER contains invalid characters." >&2
  exit 1
}

HASHED_PASS="$(printf '%s' "$BASIC_AUTH_PASS" | openssl passwd -apr1 -stdin)"
printf '%s:%s\n' "$BASIC_AUTH_USER" "$HASHED_PASS" > /tmp/.htpasswd
chmod 600 /tmp/.htpasswd
exec nginx -g 'daemon off;'
```

### nginx.conf（抜粋）
```nginx
http {
    error_log /dev/stderr warn;
    access_log /dev/stdout;
    limit_req_zone $binary_remote_addr zone=auth_zone:10m rate=5r/m;
    limit_conn_zone $binary_remote_addr zone=conn_zone:10m;
    client_max_body_size 1m;

    server {
        location / {
            limit_req zone=auth_zone burst=10 nodelay;
            limit_conn conn_zone 20;
            try_files $uri $uri/ /index.html;
        }
    }
}
```

### docker-compose.yml（抜粋）
```yaml
services:
  web:
    ports:
      - "127.0.0.1:8314:8080"
    mem_limit: 256m
    cpus: "0.50"
    pids_limit: 100
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8080/ || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

---

以上。
