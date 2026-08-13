# Data Guide

## `data/board.json`(盤面の自動生成設定)

盤面のマス配置そのものはもう `board.json` に直接書きません。**盤面のグラフは `New` を押すたび(=`GameState.new_game()`のたびに) `scripts/BoardGenerator.gd` が `data/board.json` の設定に従ってランダムに作り直します**。

盤面は `columns` x `rows` の格子を隙間なく敷き詰め、桃鉄のマップのように上下左右へマスがぎっしり並んだグリッドになります。開始マスは左上、ボスはスタートから最も離れたマスに置かれます。各マスの `next_ids` は**双方向**のつながり(道)を表し、隣り合うマス同士がランダムに道でつながります(間引かれて盤面が分断されないよう、孤立しそうなマスは自動で救済してつなぎ直します)。

**進み方**: 「次へ進む」でサイコロ(1〜6)を振り、出目の数だけ道を辿って進みます。今いるマスに複数の道があっても、直前に来た道を戻るだけなら自動でまっすぐ歩き続けます。直前に来た道を除いても2方向以上に進める分かれ道に着くと、出目が余っていてもそこで足を止め、**プレイヤーが自分でどちらに進むか選びます**(来た道を戻る選択肢も含めて自由に選べます)。選ぶと、余っていた出目はそのまま消化されて選んだ先へ進み続けます。行き止まり(道が1本しかなく、それが今来た道だけ)に入り込んだ場合は、来た道を引き返しながら残りの出目を消化します。ボスマスは、出目がいくつ余っていても必ずそこで足を止めて戦闘になります。

サイコロの出目で通過しただけのマス(足を止めなかったマス)では、育成/イベント/戦闘などのマス効果は発生しません(移動コストや危険度の変化はマスごとに発生します)。実際に足を止めたマスでだけ、マス効果とイベント絵/テキストが再生されます。

セーブデータには、そのとき生成された盤面自体も一緒に保存されます。ロードすると、セーブ時と同じ盤面に復元されます(ロードのたびに新しい盤面が生成されるわけではありません)。

### `board.json` の主なフィールド

```json
{
  "grid": {
    "columns": 9,
    "rows": 7,
    "edge_keep_chance": 0.62
  },
  "start": { "label": "START", "description": "..." },
  "boss": { "labels": ["試練の間", "..."], "description": "..." },
  "route_profiles": ["safe", "training", "danger", "reward", "recovery"],
  "type_weights": { "train": 25, "event": 22, "encounter": 25, "rest": 14, "shop": 14 },
  "tiles": {
    "train":     { "labels": [...], "stats": ["str", "charm", "mind", "all"], "descriptions": [...] },
    "event":     { "labels": [...], "categories": ["daily", "resolve", "story"], "descriptions": [...] },
    "encounter": { "labels": [...], "strong_chance": 0.3, "descriptions": [...] },
    "rest":      { "labels": [...], "descriptions": [...] },
    "shop":      { "labels": [...], "descriptions": [...] }
  }
}
```

- `grid.columns` / `grid.rows`: 盤面のマス目の列数・行数。この格子を隙間なく敷き詰めるので、マス数は概ね `columns × rows` になります(9x7なら63マス)。
- `grid.edge_keep_chance`: 各マスを右隣・下隣とつなぐ確率(0〜1)。高いほど分岐・合流が多い密な網目に、低いほどまばらな一本道寄りになります。
- `start` / `boss`: 拠点(左上に配置)とボス(右下に配置)の見た目(ラベル・本文)。ボスは `labels` からランダムに1つ選ばれます。
- `route_profiles`: 分岐先に割り振るルート特性のプール。分岐するマスの行き先ごとに、ここから重複しないよう順番に割り当てます(`safe`、`training`、`danger`、`reward`、`recovery` の意味は元々の設計と同じです)。
- `type_weights`: 拠点/ボス以外のマスの種類(`train`/`event`/`encounter`/`rest`/`shop`)の抽選重み。
- `tiles.<type>.labels` / `descriptions`: その種類のマスのラベルと本文をランダムに選ぶための候補プール。
- `tiles.train.stats`: 育成マスで伸ばすステータス(`str`/`charm`/`mind`/`all`)の候補。
- `tiles.event.categories`: イベントマスで使う `data/events.json` のカテゴリ(`daily`/`resolve`/`story`)の候補。
- `tiles.encounter.strong_chance`: 遭遇マスが強敵ルート(`strong: true`)になる確率。

盤面の見た目やバランスを変えたい場合は、これらの数値・候補プールを編集してください。特定の固定レイアウトが必要な場合は `scripts/BoardGenerator.gd` の `generate()` を直接差し替えることもできます。

## `data/events.json`

イベント本文、画像、選択肢、効果を定義します。

`adult_only: true` のイベントは、ゲーム画面右上の `18+素材` が有効な時だけ抽選されます。現在の前提では、成人向け素材はマップ上の通常マスではなく、敗北時の `defeat` カテゴリで再生します。

使える `effects`:

- `str`: 筋力
- `charm`: 魅力
- `mind`: 知性
- `resolve`: 覚悟
- `hp`: HP
- `stamina`: スタミナ
- `gold`: ゴールド
- `max_hp`: 最大HP
- `max_stamina`: 最大スタミナ

## `data/enemies.json`

敵データを定義します。

- `hp`: 敵HP
- `attack`: 敵攻撃力
- `reward_gold`: 勝利時ゴールド
- `reward_resolve`: 勝利時覚悟

## `data/characters.json`

初期主人公データを定義します。
