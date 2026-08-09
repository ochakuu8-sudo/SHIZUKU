# Build and Deploy

このプロジェクトは、同じGodotプロジェクトからWeb版とPC版を並行ビルドします。

## Web版

`main` ブランチにpushすると、GitHub ActionsがWeb exportを作り、GitHub Pagesへデプロイします。

公開URLの想定:

```text
https://ochakuu8-sudo.github.io/SHIZUKU/
```

GitHub側で Pages の source が `GitHub Actions` になっていない場合は、リポジトリの `Settings > Pages` で変更してください。

## Windows PC版

同じGitHub ActionsでWindows向け `.exe` を作り、Actions artifact として `SHIZUKU-windows.zip` を保存します。

## ローカルPCでの確認

Godot 4.5 でプロジェクトを開き、そのまま実行できます。

```powershell
& "C:\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe" --path . --quit-after 8
```

## NSFW素材について

GitHub Pagesは公開URLになります。成人向けの文章や画像を入れる前は、必ず公開範囲を確認してください。
