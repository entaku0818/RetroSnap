# 0.3.2 / build 9 提出記録

- App Store version ID: `d1499287-6a70-44a3-8965-9ff2fdd1dee8`
- Release type: `MANUAL`（承認後に手動公開）
- Archive / IPA export: 成功
- Releaseアプリ内のRevenueCat公開SDKキー設定: 確認済み（キー自体は記録しない）
- Upload: 成功。Delivery UUID `b70b326a-cce3-4159-aa2d-ab10f45f6ab3`
- 白黒・淡色の未購入プレビュー/保存制御UIテスト: 2件成功
- 実機/Sandboxでの新商品の購入完了・復元: 未検証
- 課金商品 `6824490662` / `6824490400`: 既存商品と同じ175地域、審査メモ、審査用画像を設定。両商品 `READY_TO_SUBMIT`、画像 `COMPLETE` を確認。
- 6言語のリリースノート、日英のASO文とサブタイトルを0.3.2に設定。
- レビュー連絡先は既存設定を継承。ログイン不要、カメラ購入/復元手順を審査メモに記載。

## 画像

`iap-review/` は今回のUIテストが撮影した、白黒・淡色の選択画面。シミュレーターのサンプル入力を使用。

`screenshots/` は公開用の日英各2枚（1320×2868）。既存の実写入り撮影画面素材を再利用し、8台・無料3台・買い切りの説明に更新。画像内のUI言語を各ロケールに合わせ、全4枚を目視確認。新3台それぞれの実写を見せる5枚構成は別途改善可能。

再生成: リポジトリルートから `swift docs/release-0.3.2/render-screenshots.swift`。

## 最終状態

ビルド処理・画像アップロード・審査提出の結果は、この下に追記する。

- 日英各2枚のストア画像: アップロード済み、全4枚の `assetDeliveryState=COMPLETE` を確認。
- Build Upload APIでビルド9が `PROCESSING`、errors/warningsなしと確認。アップロード成功と審査提出完了は別の状態。

## 提出完了

2026-10-20 09:25 JST に提出。

- Review submission ID: `52b3ca77-bcdd-4225-a05c-85bd4b2654a2`
- App 0.3.2 / build 9: `WAITING_FOR_REVIEW`
- 白黒フィルム `6824490662`: `WAITING_FOR_REVIEW`
- 淡色フィルム `6824490400`: `WAITING_FOR_REVIEW`
- 提出項目3件が `READY_FOR_REVIEW`、submissionが `WAITING_FOR_REVIEW` であることを再取得で確認。
- 承認後の公開設定は `MANUAL`。まだ公開していない。
