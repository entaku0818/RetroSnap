# App Store メタデータ

App Store Connect のメタデータをリポジトリで版管理する。反映は launchpad から行う。

```bash
launchpad ios metadata      # このディレクトリの内容を App Store Connect へ反映
launchpad ios aso lint      # 文字数・バイト数の検査
```

## launchpad が反映するもの / しないもの

`launchpad ios metadata` が App Store Connect へ送るのは以下のファイルだけ
（`Sources/launchpad/Commands/iOS/IOSMetadataCommand.swift` の `fields`）。

| ファイル | ASC のフィールド | 反映 |
|---|---|---|
| `description.txt` | 説明文 | ✅ |
| `keywords.txt` | キーワード | ✅ |
| `release_notes.txt` | このバージョンの新機能 | ✅ |
| `promotional_text.txt` | プロモーション用テキスト | ✅ |
| `support_url.txt` | サポートURL | ✅ |
| `marketing_url.txt` | マーケティングURL | ✅ |
| `name.txt` | アプリ名 | ❌ **反映されない**（`ios aso` の文字数検査に使うだけ） |
| `subtitle.txt` | サブタイトル | ❌ **反映されない**（同上） |

**アプリ名・サブタイトル・カテゴリは App Store Connect 上で直接変更する必要がある。**

空のファイル・存在しないファイルは送信対象から外れる（該当フィールドは現状維持）。

## 現在このディレクトリに無いもの（意図的）

以下は **App Store Connect 上の現在値を確認できていないため、あえて置いていない**。
`keywords.txt` を置くと現在のキーワードを上書きしてしまうので、
現在値を確認してから追加すること。

- `keywords.txt` — 現在値不明
- `subtitle.txt` — 現在値不明
- `name.txt` — 変更提案は issue #3 にある
- `promotional_text.txt` / `support_url.txt` / `marketing_url.txt` — 現在値不明

現在値の確認は issue #3 / #4 の作業に含まれる。

## 対応ロケール

App Store 上の対応言語は `EN` と `JA`。

- `ja/`
- `en-US/`
