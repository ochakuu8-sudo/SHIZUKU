# SHIZUKU

Godot 4.5 向けの、データ差し替え式ルート分岐育成RPGプロトタイプです。

## 起動

1. Godot 4.5 を開く
2. `project.godot` をインポート
3. `scenes/Main.tscn` またはプロジェクトの実行ボタンで起動

## 入っている機能

- サイコロ移動
- マス同士の `next_ids` でつながる分岐ルート型マップ
- 横長マップを見渡せるスクロール式マップエリア
- スマホ向けの横持ち固定表示
- 分岐点でのルート選択
- 育成ステータス: 筋力、魅力、知性、親密度
- HP、スタミナ、ゴールド
- マス効果: 育成、休息、通常イベント、親密度イベント、成人向けイベント枠、戦闘、ボス
- 選択肢つきイベント
- 簡易ターン制バトル
- セーブ/ロード
- 18+素材の有効/無効トグル

## ビルド

PC版とWeb版は同じGodotプロジェクトから作ります。

- Web: GitHub Pages向け `Web` export
- PC: Windows向け `Windows Desktop` export

詳しくは `docs/BUILD_AND_DEPLOY.md` を参照してください。

## 素材差し替え

文章と画像は `data/events.json` を編集します。画像は Godot が読める `res://` パスを指定してください。盤面の見た目とルートは `data/board.json` の `width`、`height`、各マスの `x`、`y`、`next_ids` で変えられます。マップエリアはスクロール式なので、画面より広い盤面もそのまま配置できます。

例:

```json
{
  "id": "adult_slot_custom",
  "category": "adult",
  "title": "イベント名",
  "body": "ここに用意した文章",
  "image_path": "res://assets/events/sample.png",
  "adult_only": true,
  "choices": [
    {"label": "選択肢A", "effects": {"bond": 5, "charm": 1}},
    {"label": "選択肢B", "effects": {"mind": 2}}
  ]
}
```

成人向け素材を入れる場合は、登場人物が全員成人である設定にしてください。
