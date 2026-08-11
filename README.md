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
- 育成ステータス: 筋力、魅力、知性、覚悟
- HP、スタミナ、ゴールド
- マス効果: 育成、休息、通常イベント、覚悟イベント、戦闘、ボス
- 選択肢つきイベント
- 簡易ターン制バトル
- セーブ/ロード
- 敗北時18+差し替え枠の有効/無効トグル

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
  "id": "defeat_slot_custom",
  "category": "defeat",
  "title": "敗北イベント名",
  "body": "ここに用意した成人向け敗北演出",
  "image_path": "res://assets/events/sample.png",
  "adult_only": true,
  "choices": [
    {"label": "記録して拠点へ戻る", "effects": {"resolve": 2, "charm": 1}},
    {"label": "選択肢B", "effects": {"mind": 2}}
  ]
}
```

成人向け素材は、主人公が成人女性である設定の敗北時差し替え枠として扱います。GitHub Pagesは公開URLになるため、公開範囲と素材内容を必ず確認してください。
