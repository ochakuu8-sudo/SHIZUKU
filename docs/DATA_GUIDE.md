# Data Guide

## `data/board.json`

盤面のマスを定義します。`width` と `height` がグリッドサイズ、各マスの `x` と `y` が表示位置です。進行順は各マスの `next_ids` で定義します。

現在の初期盤面は 22x11 グリッドです。STARTから横長に進み、複数回の分岐と合流を経て最後にボスへ向かうルート型マップです。画面より広い盤面は、ゲーム内のマップエリアをスクロールして見渡せます。

主なフィールド:

- `id`: マスID。プレイヤー位置や `next_ids` の参照先になります。
- `x`, `y`: グリッド上の表示位置です。
- `type`: マス効果の種類です。
- `next_ids`: 次に進めるマスIDの配列です。2つ以上あると分岐選択になります。
- `route_label`: 分岐選択ボタンに表示する名前です。省略時は `label` を使います。
- `strong`: `encounter` で `true` にすると強めの敵が出やすくなります。
- `description`: マスに停止した時のイベント本文として使われます。
- `image_path`: マスに停止した時のイベント絵です。省略時は仮ビジュアルが自動表示されます。

主な `type`:

- `start`: 拠点
- `fork`: 分岐点
- `train`: 自動トレーニング
- `event`: イベント再生
- `encounter`: 通常戦闘
- `rest`: 回復
- `shop`: ゴールド獲得
- `boss`: ボス戦

すべてのマスは、停止時にイベント絵とテキストを表示します。`event` マスでは `category` が `data/events.json` のイベントカテゴリと対応し、選択肢つきイベントを再生します。それ以外のマスは、マス効果を処理したうえで `description` を使った到着シーンを表示します。

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
