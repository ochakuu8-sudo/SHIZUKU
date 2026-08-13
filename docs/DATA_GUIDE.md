# Data Guide

## `data/board.json`(盤面の自動生成設定)

盤面のマス配置そのものはもう `board.json` に直接書きません。**「次へ進む」でサイコロ(1〜6)を振り、出目の数だけ`next_ids`を辿って一本道を進む**」「途中で分岐(`next_ids` が2つ以上あるマス)に着いたら、出目が余っていてもそこで足を止めてルート選択になり、選ぶと残りの出目でそのまま進み続ける」という進行ルールは以前と同じですが、**盤面のグラフそのものは `New` を押すたび(=`GameState.new_game()`のたびに) `scripts/BoardGenerator.gd` が `data/board.json` の設定に従ってランダムに作り直します**。桃鉄のようにマス目がグリッド状に詰まり、線が交差・合流する盤面になるようにしてあります。

サイコロの出目で通過しただけのマス(止まらなかったマス)では、育成/イベント/戦闘などのマス効果は発生しません(移動コストや危険度の変化はマスごとに発生します)。実際に足を止めたマスでだけ、マス効果とイベント絵/テキストが再生されます。`fork` 扱いになる分岐マスとルート終端(`next_ids` が空のマス。ボス)は、出目が余っていても必ずそこで足を止めます。

セーブデータには、そのとき生成された盤面自体も一緒に保存されます。ロードすると、セーブ時と同じ盤面に復元されます(ロードのたびに新しい盤面が生成されるわけではありません)。

### `board.json` の主なフィールド

```json
{
  "grid": {
    "columns": 15,
    "rows": 8,
    "min_nodes_per_column": 2,
    "max_nodes_per_column": 4,
    "fork_chance": 0.45,
    "extra_edge_chance": 0.15
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

- `grid.columns` / `grid.rows`: 盤面のマス目の列数・行数。左端の列(x=0)が拠点、右端の列がボスの1マスだけになり、間の各列に `min_nodes_per_column`〜`max_nodes_per_column` 個のマスをランダムなyに配置します。
- `grid.fork_chance`: 各マスが次の列の2マスにつながる(=分岐になる)確率。
- `grid.extra_edge_chance`: 密度を上げるための追加の交差リンクが生える確率。
- `start` / `boss`: 拠点とボスマスの見た目(ラベル・本文)。ボスは `labels` からランダムに1つ選ばれます。
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
