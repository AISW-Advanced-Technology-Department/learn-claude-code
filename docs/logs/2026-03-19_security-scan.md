# セキュリティスキャンレポート

- **日時**: 2026-03-19
- **対象リポジトリ**: `/home/ushimaru/dc/Copilot/learn-claude-code`
- **スキャン実施者**: セキュリティアナリスト（AI自動スキャン）
- **スキャンツール**: 静的解析（grep/パターンマッチング）、依存関係分析、設定ファイル検査

---

## 総合評価: ✅ Safe（本番利用時はハードニング推奨）

本リポジトリは教育目的のAIエージェントフレームワーク学習教材であり、**悪意あるコード、バックドア、データ窃取、暗号通貨マイニングなどの重大なセキュリティ脅威は検出されませんでした**。検出された項目は設計上の意図的な実装パターンまたは軽微な改善提案です。

> **注**: 本番環境での利用を想定する場合、セキュリティヘッダーの追加やHTMLサニタイズの強化など、ハードニング作業が推奨されます。教育・学習用途としてはSafeです。

---

## 検出された問題一覧

### 🔴 Critical（重大）

**検出なし**

---

### 🟠 High（高）

#### H-1: `subprocess.run(..., shell=True)` による コマンド実行（教育コード）

| 項目 | 内容 |
|---|---|
| **重要度** | High（ただし意図的設計） |
| **該当ファイル** | `agents/s01_agent_loop.py` (L59), `agents/s02_tool_use.py` (L53), `agents/s03_todo_write.py` (L104), `agents/s04_subagent.py` (L58), `agents/s05_skill_loading.py` (L129), `agents/s06_context_compact.py` (L136), `agents/s07_task_system.py` (L142), `agents/s08_background_tasks.py` (L70, L126), `agents/s09_agent_teams.py` (L268), `agents/s10_team_protocols.py` (L309), `agents/s11_autonomous_agents.py` (L387), `agents/s12_worktree_task_isolation.py` (L383, L492), `agents/s_full.py` (L85, L342) |
| **説明** | 全てのエージェント実装で `subprocess.run(command, shell=True)` を使用してbashツールを実装しています。LLMが生成したコマンド文字列がそのままシェルに渡されます。 |
| **リスク** | プロンプトインジェクション攻撃により、任意のシステムコマンドが実行される可能性があります。 |
| **緩和要因** | これはAIエージェントのbashツール実装として**意図的な設計**です。実際のClaude Codeも同様のアーキテクチャを採用しています。教育目的のサンプルコードであり、本番環境での利用を想定していません。 |
| **推奨対応** | ドキュメントに「本番環境では使用しないこと」「サンドボックス環境での実行を推奨」の注意書きを追加。 |

---

### 🟡 Medium（中）

#### M-1: インボックスファイルパスのサニタイズ不足

| 項目 | 内容 |
|---|---|
| **重要度** | Medium |
| **該当ファイル** | `agents/s09_agent_teams.py` (L95-96, L101), `agents/s10_team_protocols.py` (L105-106, L111), `agents/s11_autonomous_agents.py` (L98-100, L104), `agents/s_full.py` (L374-375, L379) |
| **説明** | チームメンバーの名前からインボックスファイルパスを構築する際に、パスサニタイズが行われていません（例: `self.dir / f"{name}.jsonl"`）。 |
| **リスク** | 名前に `../` 等を含む文字列が使用された場合、パストラバーサルによる任意のファイル読み書きの可能性があります。 |
| **緩和要因** | 教育目的のコードであり、チームメンバー名はコード内でハードコードまたはLLMが生成するため、外部ユーザー入力は想定されていません。 |
| **推奨対応** | パス構築時に `os.path.basename()` でサニタイズするか、許可された文字のみを受け付けるバリデーションを追加。 |

#### M-2: `dangerouslySetInnerHTML` によるHTML直接注入

| 項目 | 内容 |
|---|---|
| **重要度** | Medium |
| **該当ファイル** | `web/src/components/docs/doc-renderer.tsx` (L87) |
| **説明** | `dangerouslySetInnerHTML={{ __html: html }}` でMarkdownから変換されたHTMLを直接レンダリングしています。パイプラインで `allowDangerousHtml: true` (L22) が有効になっています。 |
| **リスク** | ドキュメントソース（`docs/` ディレクトリのMarkdownファイル）に悪意あるHTMLが含まれた場合、XSSの可能性があります。`rehype-raw` + `allowDangerousHtml: true` の組み合わせにより、Markdownファイル内の任意のHTMLがそのまま出力されます。サプライチェーン攻撃（ドキュメントファイルの改ざん）によるStored XSSの経路となり得ます。 |
| **緩和要因** | HTMLソースはリポジトリ内の静的Markdownファイル（`docs/en/`, `docs/ja/`, `docs/zh/`）から事前生成されたJSONデータ（`src/data/generated/docs.json`）であり、外部ユーザー入力ではありません。さらに `output: "export"` による完全静的サイトのため、サーバーサイドのXSSリスクはありません。 |
| **推奨対応** | `rehype-sanitize` プラグインをパイプラインに追加し、不要なHTML要素をフィルタリング。 |

---

### 🟢 Low（低）

#### L-1: セキュリティヘッダー未設定

| 項目 | 内容 |
|---|---|
| **重要度** | Low |
| **該当ファイル** | `web/next.config.ts`, `web/vercel.json` |
| **説明** | CSP（Content-Security-Policy）、X-Frame-Options、X-Content-Type-Options、Referrer-Policy 等のセキュリティヘッダーが設定されていません。また、`layout.tsx` のインラインスクリプトにより、厳格なCSP導入時にはnonce/hashベースの設定が必要です。 |
| **緩和要因** | `output: "export"` による完全静的サイトであり、サーバーサイドの脆弱性リスクは限定的です。Vercelのデフォルトセキュリティヘッダーが一部保護を提供します。 |
| **推奨対応** | 本番デプロイ時にはVercelの `headers` 設定でCSP等のセキュリティヘッダーを追加。 |

#### L-2: `.gitignore` でのIDE設定ファイル除外がコメントアウト

| 項目 | 内容 |
|---|---|
| **重要度** | Low |
| **該当ファイル** | `.gitignore` (L178, L191) |
| **説明** | `.idea/` と `.vscode/` のgitignoreエントリがコメントアウトされています。 |
| **リスク** | IDE設定ファイルがリポジトリに含まれる可能性があり、デバッグ設定やローカルパス情報が漏洩する可能性があります。 |
| **推奨対応** | プロジェクトの方針として、共有すべきIDE設定がなければコメントを外す。 |

---

### ℹ️ Info（情報）

#### I-1: ダークモード検出用のインラインスクリプト

| 項目 | 内容 |
|---|---|
| **重要度** | Info |
| **該当ファイル** | `web/src/app/[locale]/layout.tsx` (L41-48) |
| **説明** | `dangerouslySetInnerHTML` で、ダークモード検出のためのインラインスクリプトを挿入しています。 |
| **評価** | 内容はローカルストレージの読み取りとCSSクラスの適用のみで、外部通信やデータ送信はありません。Next.jsでFOUC（Flash of Unstyled Content）を防ぐための一般的なパターンです。**問題なし**。 |

#### I-2: GitHub リポジトリへの外部リンク

| 項目 | 内容 |
|---|---|
| **重要度** | Info |
| **該当ファイル** | `web/src/components/layout/header.tsx` (L98, L154) |
| **説明** | `https://github.com/shareAI-lab/learn-claude-code` へのリンクが含まれています。 |
| **評価** | 単純な `href` リンクであり、データ送信やfetchリクエストではありません。プロジェクトのGitHubリポジトリへの参照リンクです。**問題なし**。 |

#### I-3: `.env.example` のプレースホルダーAPIキー

| 項目 | 内容 |
|---|---|
| **重要度** | Info |
| **該当ファイル** | `.env.example` (L3) |
| **説明** | `ANTHROPIC_API_KEY=sk-ant-xxx` というプレースホルダーが記載されています。 |
| **評価** | 実際のAPIキーではなく、テンプレート用のプレースホルダーです。**問題なし**。 |

#### I-4: 環境変数経由でのAPIキー読み取り

| 項目 | 内容 |
|---|---|
| **重要度** | Info |
| **該当ファイル** | `skills/agent-builder/references/minimal-agent.py` (L20), `skills/agent-builder/scripts/init_agent.py` (L37, L97) |
| **説明** | `os.getenv()` で環境変数からAPIキーを取得しています。 |
| **評価** | セキュリティのベストプラクティスに従った実装です。ハードコードされたキーはありません。**問題なし**。 |

---

## スキャン詳細

### 1. コードの静的解析

#### web/src/ TypeScript/JSXファイル（51ファイル）

| チェック項目 | 結果 |
|---|---|
| `eval()` / `new Function()` | ❌ 検出なし |
| 外部URLへのデータ送信（fetch/axios/XMLHttpRequest） | ❌ 検出なし |
| 暗号通貨マイニングコード | ❌ 検出なし |
| シェルコマンド実行（child_process） | ❌ 検出なし |
| ファイルシステムへの不審な書き込み | ❌ 検出なし |
| Base64エンコードされた不審な文字列 | ❌ 検出なし |
| 難読化されたコード | ❌ 検出なし |
| バックドア・リバースシェル | ❌ 検出なし |
| `dangerouslySetInnerHTML` | ⚠️ 2箇所（上記M-2, I-1に記載） |

#### agents/ Pythonファイル（14ファイル）

| チェック項目 | 結果 |
|---|---|
| `eval()` / `exec()` / `compile()` | ❌ 検出なし |
| `os.system()` / `os.popen()` | ❌ 検出なし |
| 外部URLへのデータ送信（requests/urllib） | ❌ 検出なし |
| 暗号通貨マイニングコード | ❌ 検出なし |
| pickle/デシリアライゼーション | ❌ 検出なし |
| Base64エンコードされた不審な文字列 | ❌ 検出なし |
| 難読化されたコード | ❌ 検出なし |
| バックドア・リバースシェル | ❌ 検出なし |
| SQL インジェクション | ❌ 検出なし |
| `subprocess.run(shell=True)` | ⚠️ 13/14ファイル（上記H-1に記載、意図的設計） |
| パストラバーサル | ⚠️ 4ファイル（上記M-1に記載） |

#### web/scripts/ スクリプト（1ファイル）

| チェック項目 | 結果 |
|---|---|
| `extract-content.ts` | ✅ 安全。ファイル読み書きは全てリポジトリ内のパスに限定。`RegExp.exec()` の使用のみ（コード実行ではない）。 |

---

### 2. npm依存関係の脆弱性チェック

#### package.json 依存関係分析

| パッケージ | バージョン | 正当性 | 評価 |
|---|---|---|---|
| `diff` | ^8.0.3 | ✅ 正規パッケージ (kpdecker/jsdiff) | 安全 |
| `framer-motion` | ^12.34.0 | ✅ 正規パッケージ (Framer) | 安全 |
| `lucide-react` | ^0.564.0 | ✅ 正規パッケージ (Lucide Icons) | 安全 |
| `next` | 16.1.6 | ✅ 正規パッケージ (Vercel) | 安全 |
| `react` | 19.2.3 | ✅ 正規パッケージ (Meta) | 安全 |
| `react-dom` | 19.2.3 | ✅ 正規パッケージ (Meta) | 安全 |
| `rehype-highlight` | ^7.0.2 | ✅ 正規パッケージ (unified) | 安全 |
| `rehype-raw` | ^7.0.0 | ✅ 正規パッケージ (unified) | 安全 |
| `rehype-stringify` | ^10.0.1 | ✅ 正規パッケージ (unified) | 安全 |
| `remark-gfm` | ^4.0.1 | ✅ 正規パッケージ (unified) | 安全 |
| `remark-parse` | ^11.0.0 | ✅ 正規パッケージ (unified) | 安全 |
| `remark-rehype` | ^11.1.2 | ✅ 正規パッケージ (unified) | 安全 |
| `tsx` | ^4.21.0 | ✅ 正規パッケージ (esbuild-kit) | 安全 |
| `unified` | ^11.0.5 | ✅ 正規パッケージ (unified) | 安全 |
| `@tailwindcss/postcss` | ^4 | ✅ 正規パッケージ (Tailwind Labs) | 安全 |
| `@types/diff` | ^7.0.2 | ✅ 正規パッケージ (DefinitelyTyped) | 安全 |
| `@types/node` | ^20 | ✅ 正規パッケージ (DefinitelyTyped) | 安全 |
| `@types/react` | ^19 | ✅ 正規パッケージ (DefinitelyTyped) | 安全 |
| `@types/react-dom` | ^19 | ✅ 正規パッケージ (DefinitelyTyped) | 安全 |
| `tailwindcss` | ^4 | ✅ 正規パッケージ (Tailwind Labs) | 安全 |
| `typescript` | ^5 | ✅ 正規パッケージ (Microsoft) | 安全 |

- **タイポスクワッティング**: 検出なし
- **不審なパッケージ**: 検出なし
- **不正なバージョン指定**: 検出なし
- **npm audit**: ローカルのNodeバージョン(v12)が古いためスキップ。package.json内容から手動分析を実施。

#### requirements.txt Python依存関係

| パッケージ | バージョン | 評価 |
|---|---|---|
| `anthropic` | >=0.25.0 | ✅ 正規パッケージ (Anthropic公式SDK) |
| `python-dotenv` | >=1.0.0 | ✅ 正規パッケージ |

---

### 3. 設定ファイルの検査

#### next.config.ts
```typescript
const nextConfig: NextConfig = {
  output: "export",          // 静的サイト生成 - 安全
  images: { unoptimized: true },  // 画像最適化無効 - セキュリティ影響なし
  trailingSlash: true,       // URL末尾スラッシュ - セキュリティ影響なし
};
```
**評価**: ✅ 安全。最小限の設定で、危険なリダイレクト、ヘッダー操作、実験的機能の有効化はありません。

#### vercel.json
```json
{
  "redirects": [
    { "source": "/:path(.*)", "destination": "https://learn.shareai.run/:path", "permanent": true },
    { "source": "/", "destination": "/en", "permanent": false }
  ]
}
```
**評価**: ✅ 安全。リダイレクト先は固定ドメイン（`learn.shareai.run`）であり、ユーザー入力に依存したオープンリダイレクトの脆弱性はありません。

#### tsconfig.json
**評価**: ✅ 安全。`strict: true` が有効で、標準的なNext.js設定です。セキュリティに影響する危険な設定はありません。

#### postcss.config.mjs
**評価**: ✅ 安全。`@tailwindcss/postcss` プラグインのみ使用。

---

### 4. 機密情報の漏洩チェック

| チェック項目 | 結果 |
|---|---|
| ハードコードされたAPIキー | ❌ 検出なし |
| AWSクレデンシャル | ❌ 検出なし |
| GitHubトークン | ❌ 検出なし |
| パスワード | ❌ 検出なし |
| 秘密鍵（PEM等） | ❌ 検出なし |
| データベース接続文字列 | ❌ 検出なし |
| JWTトークン | ❌ 検出なし |
| Slackトークン/Webhook | ❌ 検出なし |

#### .gitignore の適切さ

| 項目 | ルートの.gitignore | web/.gitignore |
|---|---|---|
| `.env` | ✅ | ✅ (`.env*`) |
| `.env*.local` | ✅ | ✅ |
| `node_modules/` | ✅ (`web/node_modules/`) | ✅ |
| `.next/` | ✅ (`web/.next/`) | ✅ |
| `*.pem` | - | ✅ |
| `.vscode/` | ⚠️ コメントアウト | - |
| `.idea/` | ⚠️ コメントアウト | - |

---

## 推奨アクション（優先度順）

1. **（任意）** agents/ ディレクトリのREADMEに「教育目的のコードであり、本番環境での使用は推奨しない」旨の免責事項を明記
2. **（任意）** `doc-renderer.tsx` のrehypeパイプラインに `rehype-sanitize` を追加（Stored XSS対策）
3. **（任意）** インボックスパス構築時に `os.path.basename()` または正規表現 `^[a-zA-Z0-9_-]+$` でファイル名サニタイズを追加（agents/s09, s10, s11, s_full）
4. **（任意）** 本番デプロイ時にVercelの `headers` 設定でCSP等のセキュリティヘッダーを追加
5. **（任意）** `.gitignore` でIDE設定ファイルの除外を有効化

---

## 結論

本リポジトリは、Claude Codeの内部アーキテクチャを学ぶための教育用プロジェクトとして適切に構築されています。

- **悪意あるコード**: 検出なし
- **データ窃取**: 検出なし
- **暗号通貨マイニング**: 検出なし
- **バックドア/リバースシェル**: 検出なし
- **サプライチェーン攻撃（npm）**: 検出なし
- **機密情報の漏洩**: 検出なし

`subprocess.run(shell=True)` の使用はAIエージェントのbashツール実装として意図的であり、教育コードとしては妥当です。全体として**教育・学習用途としてはSafe（安全）**と評価します。本番環境への適用時にはセキュリティヘッダーの追加・HTMLサニタイズの強化等のハードニングを推奨します。

---

## レビュー履歴

| レビュアー | モデル | ロール | 結果 |
|---|---|---|---|
| review-report-gemini | gemini-3-pro-preview | Lead Security Auditor | ✅ Verified Accurate and Complete |
| review-report-gpt | gpt-5.3-codex | Senior Penetration Tester | ⚠️ CSPヘッダー未設定・rehypeRawリスクの追記を提案 → 反映済み |
