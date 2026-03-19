# セキュリティ監査レビュー結果 (Role: DevSecOps Engineer)

## 1. 監査ドラフトの総評
提示された監査ドラフト（`security-audit-draft-gpt.md`）は、コンテナセキュリティのベストプラクティス（非root実行、Read-only FS、Capability Drop等）を網羅しており、指摘事項の多くは正確かつ適切です。
しかし、**提案された修正案の一部に、実装するとサービスが正常稼働しなくなる致命的な欠陥（ヘルスチェック設定）**が含まれています。また、リポジトリ固有のファイル構成を踏まえた除外設定の具体性に欠ける部分があります。

本レビューでは、これらの「実装時の実害」に焦点を当てて補正を行います。

## 2. 重大な見落とし・修正案の欠陥

### 🔴 Critical: HealthcheckがBasic認証により失敗する (C-03)
ドラフトで提案されている以下のヘルスチェック設定は、認証エラーにより機能しません。

> `test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8080/ || exit 1"]`

- **問題**: nginxの設定でルートパス `/` 全体に `auth_basic` がかかっています。`wget` は認証情報を付与していないため `401 Unauthorized` を受け取り、終了コード `1` を返します。
- **結果**: コンテナが常に `Unhealthy` 判定となり、オーケストレーターにより再起動ループに陥る可能性があります。
- **修正案**: ヘルスチェック専用の除外パスを作成することを推奨します。

**nginx.conf 修正案:**
```nginx
server {
    # ... 既存設定 ...
    
    # ヘルスチェック用エンドポイント（認証除外）
    location /health {
        access_log off;
        auth_basic off;
        return 200 "healthy";
    }

    location / {
        # ... 認証設定 ...
    }
}
```
**docker-compose.yml 修正案:**
```yaml
test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8080/health || exit 1"]
```

### 🟠 High: ビルドコンテキストへの不要ディレクトリ混入 (D-02, G-02関連)
ドラフトでは `COPY . .` のリスクを指摘していますが、`.dockerignore` の修正案が一般的な拡張子（`*.pem`等）の除外に留まっています。
本リポジトリの構造上、`docker-compose.yml` で `context: ..` （ルートディレクトリ）を指定しているため、以下のディレクトリがビルドコンテキストおよび `builder` ステージにコピーされます。

- **漏れているディレクトリ**:
    - `docs/` (監査ログやドキュメント)
    - `agents/` (エージェント定義)
    - `skills/` (スキル定義)
    - `deploy/` (自分自身以外のデプロイ設定)
    - `SECURITY_AUDIT_FINAL.md` 等のルートファイル

これらに機密情報（プロンプトやログ内のクレデンシャル等）が含まれていた場合、Dockerイメージのレイヤー履歴に残るリスクがあります。

**修正案**: `.dockerignore` に以下を追記すべきです。
```text
docs/
agents/
skills/
*.md
LICENSE
TODO.md
rehype-test.js
requirements.txt
```

## 3. ドラフト指摘事項の技術的検証・補足

### Docker Secrets への移行 (C-05)
ドラフトの「Compose secretsへ移行」という指摘は正しいですが、具体的な実装手順が不足しています。以下の変更が必要です。

1.  **docker-compose.yml**:
    ```yaml
    services:
      web:
        # environment から BASIC_AUTH_* を削除またはダミー化
        secrets:
          - basic_auth_user
          - basic_auth_password
    
    secrets:
      basic_auth_user:
        file: ./secrets/basic_auth_user.txt  # ローカルのパス
      basic_auth_password:
        file: ./secrets/basic_auth_password.txt
    ```

2.  **start.sh**: 環境変数ではなくファイルから読み込む処理に変更。
    ```sh
    # Secretsが存在する場合、ファイルから読み込む
    if [ -f /run/secrets/basic_auth_user ]; then
      BASIC_AUTH_USER=$(cat /run/secrets/basic_auth_user)
    fi
    if [ -f /run/secrets/basic_auth_password ]; then
      BASIC_AUTH_PASS=$(cat /run/secrets/basic_auth_password)
    fi
    
    # ... 以降のチェックロジック ...
    ```

### nginxエラーページとバージョン隠蔽 (N-見落とし)
現状 `server_tokens off;` が設定されているため、デフォルトエラーページが表示されてもバージョン番号は漏洩しません。しかし、"nginx" というサーバーソフトウェア名は表示されます。
セキュリティ上のSeverityは **Low** ですが、ユーザビリティの観点からカスタム404ページの導入を検討しても良いでしょう。Next.jsのエクスポート成果物に `404.html` が含まれている場合、以下のように設定します。

```nginx
error_page 404 /404.html;
location = /404.html {
    internal;
}
```

### start.sh の POSIX互換性 (S-01)
`nginx:alpine` は `ash` (BusyBox) を使用しており、`$'\n'` 記法（ANSI-C quoting）はシェルによっては解釈されない可能性があります。ドラフトの指摘通り、`grep` を用いるか、標準的な記述に直すのが安全です。ドラフトの修正案は適切です。

## 4. 誤検知（False Positive）の確認
ドラフト内の指摘で、明確な誤りや過剰反応と判断されるものはありませんでした。すべて適切なリスク評価に基づいています。

## 5. 最終的な修正ロードマップ（推奨）

ドラフトの優先度定義を以下のように調整することを推奨します。

1.  **即時修正 (Critical)**:
    - ヘルスチェックの導入（ただし `/health` エンドポイント作成とセットで実装すること）
2.  **優先対応 (High)**:
    - イメージDigestの固定
    - `start.sh` の引数渡し廃止 & POSIX互換性修正
    - `.dockerignore` へのリポジトリ固有ディレクトリ追加 (`docs/`, `agents/` 等)
3.  **推奨 (Medium)**:
    - Dockerfileの選択的COPYへの変更 (`COPY web/package*.json ./` 等)
    - nginxのレート制限実装
    - Docker Secretsへの移行

以上
