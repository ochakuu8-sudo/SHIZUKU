# Build and Deploy

このプロジェクトは、同じGodotプロジェクトからWeb版とPC版を並行ビルドします。

## Web版

`main` ブランチにpushすると、GitHub ActionsがWeb exportを作り、`gh-pages` ブランチへ配置します。
スマホでは縦持ち/横持ちの両方でプレイできます。マップエリアは空いている場所をドラッグ/スワイプして、広い盤面全体を見渡せます。

公開URLの想定:

```text
https://ochakuu8-sudo.github.io/SHIZUKU/
```

GitHub側で一度だけ、リポジトリの `Settings > Pages` から source を `Deploy from a branch`、branch を `gh-pages`、folder を `/ (root)` にしてください。

## Windows PC版

同じGitHub ActionsでWindows向け `.exe` を作り、Actions artifact として `SHIZUKU-windows.zip` を保存します。

## ローカルPCでの確認

Godot 4.5 でプロジェクトを開き、そのまま実行できます。

```powershell
& "C:\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe" --path . --quit-after 8
```

## 自動テスト

`tests/test_runner.gd` に、外部アドオンに依存しないヘッドレステストがあります。盤面データの整合性やバトル/育成ロジックの不変条件を検証します。GitHub Actionsではビルド前に自動実行されます。ローカルで実行する場合:

```bash
godot --headless --script res://tests/test_runner.gd
```

全チェックに通ると `OK: N checks passed` と表示され、終了コード0を返します。失敗すると `FAIL: ...` の内容とともに終了コード1を返します。

## NSFW素材について

GitHub Pagesは公開URLになります。成人向けの文章や画像を入れる前は、必ず公開範囲を確認してください。
