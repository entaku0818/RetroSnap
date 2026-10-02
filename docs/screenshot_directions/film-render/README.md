# 実写の現像（スクショ素材用）

アプリの `FilmRenderer` / `CameraCatalog` をそのまま使って、写真を5台のカメラで現像する。
CoreImage のパラメータはアプリと同一（同じソースファイルをコンパイルしている）。

```bash
R=RetroSnap
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -O -target arm64-apple-ios26.0-simulator -sdk $SDK -o filmcli \
  docs/screenshot_directions/film-render/main.swift \
  $R/Camera/FilmRenderer.swift $R/Camera/CameraSpec.swift $R/Camera/CameraCatalog.swift $R/Image+extention.swift
xcrun simctl spawn <booted-device> ./filmcli <src_dir> <out_dir>   # src_dir に cafe/fountain/shibuya/beach.jpg
```

入力はぼかし・トリミング済みのもの（下記）。日付は 2026-10-02 で焼き込む。

| 元写真 (`fastlane/screenshots/source/photos/`) | 前処理 |
|---|---|
| 01 キャラのキーリング | **使わない**（他社キャラクター） |
| 02 カフェ | なし（腕は小さく顔は写っていない） |
| 03 夜の噴水 | 奥の人物の帯と店の看板をぼかし（顔が判別できたため） |
| 04 渋谷の夜景 | 右上の夜景だけをトリミング（ロゴのプレート・メニュー・ボトルを含めない） |
| 05 海辺 | なし（小さな後ろ姿のみ） |

元写真はリポジトリが PUBLIC のため commit しない（`.gitignore` 済み）。

撮影画面（`src/assets/real/{ja,en}/screen-*.jpg`）は、`SamplePreviewFrame.makeImage` を一時的に
「UserDefaults `RetroSnapSampleImagePath` の写真を返す」よう差し替えて UI テスト
（`RETROSNAP_SCREENSHOT_DIR`）で書き出したもの。差し替えは撮影後に戻しており、commit していない。
