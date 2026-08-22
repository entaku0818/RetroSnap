# RevenueCat と App Store Connect の設定手順

アプリ側の実装は入っている（`0e4b082`）。ここに書いてあるのは、**コードでは埋められない設定作業**。
順番に意味がある。ASC → RevenueCat → 手元、の順でないと商品が取り込めない。

アプリが前提にしている名前は**コードから機械導出**されている。手で決める余地は無い:

| カメラ | product ID | entitlement | 価格 |
|---|---|---|---|
| ナイトネオン | `com.entaku.retrosnap.camera.nightneon` | `camera_nightneon` | ¥300 |
| トイプラスチック | `com.entaku.retrosnap.camera.toyplastic` | `camera_toyplastic` | ¥300 |
| デートスタンプ98 | `com.entaku.retrosnap.camera.datestamp98` | `camera_datestamp98` | ¥500 |

`plain70` と `sunsetfade` は無料。**登録しない。**

---

## 1. App Store Connect で IAP を3つ作る

App Store Connect → マイApp → RetroSnap → 「App内課金」

各商品について:

- 種類: **非消耗型**（サブスクではない）
- 製品ID: 上の表のとおり。**作成後は変更も削除もできない。** 打ち間違いに注意
- 参照名: `Night Neon` / `Toy Plastic` / `Datestamp 98`（社内向けの名前。ユーザーには出ない）
- 価格: 上の表のとおり
- ローカリゼーション: 日本語と英語の2つ。表示名と説明を入れる
  - 表示名は `Localizable.xcstrings` の `camera.*.name` と揃える
  - 説明は `camera.*.tagline` を膨らませたもので良い
- ファミリー共有: **オフ**
- 審査用スクリーンショット: **商品ごとに1枚必要**。カメラストア画面か、そのカメラで撮った写真

3つとも「提出準備完了」になれば OK。

> **初回はアプリのバイナリと一緒に審査に出す必要がある。** IAP だけ先に承認されることはない。

## 2. App Store Connect でキーと通知先を設定する

RevenueCat が Apple 側の購入を検証するために要る。

1. ユーザーとアクセス → 「連携」→ **App内課金** のキーを作成し、`.p8` をダウンロード
   （ダウンロードは1回きり。無くしたら作り直し）
2. あとで RevenueCat 側にアップロードする

App Store サーバ通知の URL は、RevenueCat 側が発行するものを ASC に貼る（手順4で戻ってくる）。

## 3. RevenueCat を設定する

1. **プロジェクトを作る**（RetroSnap）
2. **App を追加**: プラットフォーム iOS、bundle ID `com.entaku.RetroSnap`
3. 手順2で作った **App内課金キー（.p8）をアップロード**
4. RevenueCat が出す **App Store サーバ通知の URL** を、ASC 側に設定する
5. **Products**: 上の3つの product ID を登録（ASC から取り込むか手で追加）
6. **Entitlements**: `camera_nightneon` / `camera_toyplastic` / `camera_datestamp98` を作り、
   それぞれに対応する product を1つずつ紐づける
   - ★ここの綴りが1文字でも違うと、購入は通るのにカメラが開かない。
     アプリはその状態を検知して「購入は完了しましたが、カメラが開きませんでした」と出す
7. **Offerings**: ★**忘れやすい。** 少なくとも1つ Offering を作り、3商品ぶんの package を入れる。
   アプリは全 Offering の package を product ID で引くので、Offering の組み方は自由だが、
   **package が1つも無いと価格が出ず、購入ボタンも出ない**
8. **API キー**: iOS の**公開 SDK キー**（`appl_` で始まる）をコピーする
   - 秘密鍵（`sk_`）ではない。アプリに埋めるのは公開キーのほう

## 4. 手元にキーを入れる

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Config/Secrets.xcconfig を開いて REVENUECAT_API_KEY に appl_ のキーを入れる
```

`Config/Secrets.xcconfig` は `.gitignore` 済み（履歴に残らない）。

そのあと Xcode で: プロジェクト → Info → Configurations →
**Debug と Release の両方**に `Secrets.xcconfig` を割り当てる。

> 割り当てを忘れると `Info.plist` の `RevenueCatAPIKey` が空のままになり、
> アプリは「課金が使えない」状態で起動する（クラッシュはしない）。

## 5. 動作を確認する

1. ASC → ユーザーとアクセス → **Sandbox テスター**を1つ作る
2. 実機の 設定 → App Store → サンドボックスアカウント にそれでサインイン
3. アプリを実機で起動 → 歯車 → カメラストア
   - **価格が出ていること**（出ていなければ手順3-7の Offering を疑う）
4. ナイトネオンを選んでシャッター → 保存されずカメラストアが出る
5. 購入 → 閉じる → 「写真が保存されました」が出る
6. アプリを消して入れ直す → 歯車 → 購入を復元 → ナイトネオンが「購入済み」に戻る

ここまで通れば、アプリ側で見るところは無い。

## 積み残し

- 実購入・復元を機械で見張るテストは無い（RevenueCat のサーバが要るため）。
  この手順5が唯一の確認手段になっている
- スクリーンショットの写真12枚が未挿入（`fastlane/screenshots/source/photos/README.md`）
- 説明文が全6ロケールとも v0.3.0 向けのまま。カメラ切替と課金に触れていない
