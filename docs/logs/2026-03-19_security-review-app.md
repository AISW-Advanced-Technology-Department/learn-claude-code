# セキュリティレビュー（アプリケーション・コード品質視点）

- レビュー対象:
  1. `docs/logs/security-audit-report.md`
  2. `docs/logs/2026-03-19_dependency-scan.md`
- レビュー日: 2026-03-19
- 前提:
  - Next.js static export (`output: "export"`)
  - 社内イントラネット配信（Docker + nginx, Basic認証）
  - 外部インターネット非公開
  - `agents/` のPythonコードはWeb実行されず、コンテンツ表示のみ

## 総評（先に結論）
現状は **「条件付きホスティング可」** と判定します。

理由は、現時点で「即時に悪用される高危険度脆弱性」は見当たらない一方で、
- `next@16.1.6` の既知脆弱性未解消
- Markdownレンダリング経路（`allowDangerousHtml: true` + `rehypeRaw` + `dangerouslySetInnerHTML`）の将来リスク
- セキュリティヘッダ/CSPの運用定義不足
が残っているためです。

---

## 1) コードレベル分析の十分性・見落とし可能性

### 評価
既存2レポートは、主要シンク（`dangerouslySetInnerHTML`, `window.location.href`, build scriptの`fs`/正規表現）に対する評価は概ね妥当です。特に「静的サイトであるため、サーバ実行型攻撃は成立しにくい」という整理は正しいです。

### 追加で見るべき（見落とし候補）
1. **Markdown由来HTMLのサニタイズ方針の明文化不足**
   - `doc-renderer.tsx` では raw HTML が許可されており、現状は「リポジトリ信頼」に依存。
   - レポートは触れているが、**許可タグ/属性の具体スキーマ**（`rehype-sanitize` 等）設計まで落ちていない。

2. **`window.location.href` の安全性を型・実装で固定していない**
   - 現状は `LOCALES` 定数由来で安全寄りだが、`switchLocale(newLocale: string)` は将来改修で緩む余地がある。
   - `newLocale` を union型化し、`router.push` + allowlist検証の方が堅い。

3. **外部リンクの `rel` 設定**
   - `noopener` はあるが `noreferrer` がない。低リスクだが情報漏えい最小化の観点で改善余地。

4. **DOM XSSの回帰検知テスト不足**
   - 「今安全」でも依存更新や仕様変更で崩れるため、悪性Markdownペイロードの回帰テストは有効。

---

## 2) ビルドパイプライン（`extract-content.ts → next build`）の検証妥当性

### 評価
- `extract-content.ts` が `child_process` を使わず、外部ダウンロードもせず、固定パスへJSON生成する点は妥当評価。
- `prebuild` で抽出実行する流れも分かりやすく、明白なRCE要素は見当たりません。

### 不足している検証
1. **ビルド入力の完全性保証**
   - 「ローカルファイルを読むから安全」ではなく、CI/リポジトリ改ざん耐性（署名、保護ブランチ、CODEOWNERS）評価が必要。
2. **生成物検証**
   - `docs.json`/`versions.json` の差分監視（異常なscript属性混入など）ルールがあるとより堅い。
3. **依存供給網のビルド時リスク**
   - `esbuild`/`sharp` などpostinstall系バイナリ依存を使うため、再現ビルド/SBOM/CI固定化の確認が必要。

---

## 3) クライアントサイド脆弱性（XSS・オープンリダイレクト等）評価の妥当性

### XSS
- 現在の評価（**条件付きリスク**）は妥当です。
- ただし、`allowDangerousHtml + rehypeRaw + dangerouslySetInnerHTML` は、コンテンツ信頼境界が1段でも崩れると即XSS化するため、実務上は「低」より**低〜中の運用リスク**として扱うのが安全です。

### オープンリダイレクト
- `window.location.href` は現実装では外部ドメインへ飛ばないため、評価は妥当。
- 将来変更耐性（型制約・allowlistテスト）の追記があるとより適切。

### 追加観点
- **CSP未設定時の被害拡大**を既存レポートが適切に指摘しており、これは重要。
- イントラ公開でも、フィッシング/社内クッキー・トークン窃取導線になり得るため、CSPは優先度高。

---

## 4) 依存関係評価の網羅性

### npm側
- `npm audit`, lockfileの `resolved`/`integrity` 確認まで実施されており、一定水準。
- `next@16.1.6` の既知脆弱性3件を特定している点は良い。

### 不足
1. **`npm audit`依存の限界補完が不足**
   - OSV/Dependabot/GitHub Advisoryの定期追跡、到達可能性評価（Reachability）まであると理想。
2. **Python側が未完**
   - `requirements.txt` が範囲指定のみでロック・ハッシュ固定なし。
   - `pip-audit`未実施は明確なギャップ。
3. **コンテナ/配信基盤依存の評価不足**
   - Dockerベースイメージ、nginxモジュール、openssl等の脆弱性は別レイヤだが、ホスティング可否判断には重要。

---

## 5) 総合安全性判断

### 判定
## **条件付きホスティング可**

### 判定理由
- 静的エクスポート + イントラ + Basic認証で、公開Webに比べ攻撃面は大幅縮小。
- 一方で、以下を満たすまで「無条件で安全」とは言えない。

### ホスティング前の必須条件（推奨ではなく実施条件）
1. `next` を **16.2.0以上**へ更新し、再監査（`npm audit`）で結果確認。
2. nginxで最低限のヘッダ適用:
   - `Content-Security-Policy`（インラインテーマスクリプトはhash許可）
   - `X-Content-Type-Options: nosniff`
   - `Referrer-Policy`
   - `X-Frame-Options` または `frame-ancestors`（CSP）
   - `Permissions-Policy`
3. Markdownレンダリング方針の固定:
   - `rehype-sanitize`導入、または raw HTML無効化（要件に応じてどちらか）
4. Python依存を含むCI監査:
   - `pip-audit -r requirements.txt` を実行可能化
5. 変更管理:
   - docs配下（特にレンダリング対象markdown）へのCODEOWNERS/レビュー必須化

---

## 補足（コンテキスト反映）
- 「外部非公開」「Basic認証あり」は重要なリスク低減要素ですが、**XSSやサプライチェーン問題の本質的解消ではありません**。
- また、`agents/` がWeb配信されない点は、Pythonコード実行リスクを実運用上ほぼ分離できており、評価上プラスです。

以上より、現コードベースは **是正条件を満たせば運用可能**、現時点では **条件付きホスティング可** です。
