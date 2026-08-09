# Data Guide

## `data/board.json`

盤面のマスを定義します。`width` と `height` がグリッドサイズ、各マスの `x` と `y` が表示位置です。`spaces` の順番がすごろくの進行順です。

現在の初期盤面は 8x8 グリッドです。外周28マスが進行ルートで、内側セルは空きマスとして薄く表示されます。

主な `type`:

- `start`: 拠点
- `train`: 自動トレーニング
- `event`: イベント再生
- `encounter`: 通常戦闘
- `rest`: 回復
- `shop`: ゴールド獲得
- `boss`: ボス戦

`event` マスでは `category` が `data/events.json` のイベントカテゴリと対応します。

## `data/events.json`

イベント本文、画像、選択肢、効果を定義します。

`adult_only: true` のイベントは、ゲーム画面右上の `18+素材` が有効な時だけ抽選されます。

使える `effects`:

- `str`: 筋力
- `charm`: 魅力
- `mind`: 知性
- `bond`: 親密度
- `hp`: HP
- `stamina`: スタミナ
- `gold`: ゴールド
- `max_hp`: 最大HP
- `max_stamina`: 最大スタミナ

## `data/enemies.json`

戦闘相手を定義します。

- `hp`: 敵HP
- `attack`: 敵攻撃力
- `reward_gold`: 勝利時ゴールド
- `reward_bond`: 勝利時親密度

## `data/characters.json`

初期主人公データを定義します。
