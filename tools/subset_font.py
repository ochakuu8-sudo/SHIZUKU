#!/usr/bin/env python3
"""assets/fonts/NotoSansCJKjp-Regular.otf をゲーム内で実際に使われている文字だけの
サブセットに作り直すスクリプト。

なぜ必要か:
  Noto Sans CJK JP のフル収録フォントは約16MBあり、Webビルドの配布サイズ
  (index.pck) の大半をこのフォント1つが占めていた。ゲーム内で使う文字は
  data/*.json とスクリプト内の文言だけなので、実際に使われている文字 +
  ひらがな/カタカナ全域 + 主な記号・半角英数だけに絞り込むことで、
  16MB超 -> 400KB前後まで縮小できる (実測で 16,467,736 bytes -> 364,372 bytes)。

  data/*.json をカスタム編集して、このサブセットに含まれない漢字を使った場合、
  Godot 側の allow_system_fallback=true (assets/fonts/*.otf.import) により
  OSのシステムフォントへフォールバックして表示はされる(文字化けはしない)が、
  書体がNoto Sans CJKと変わる。厳密に同じ書体で表示したい場合は、このスクリプトを
  再実行してサブセットを作り直すこと。

使い方:
  1. pip install fonttools
  2. 元のNoto Sans CJK JP (フル収録版) を用意する。
     (このリポジトリのassets/fonts/内のファイルは既にサブセット済みなので、
      再生成する場合はGoogle Fonts / Adobe配布の "NotoSansCJKjp-Regular.otf"
      フル収録版を別途取得して、--source で指定すること)
  3. python3 tools/subset_font.py --source /path/to/full/NotoSansCJKjp-Regular.otf
  4. assets/fonts/NotoSansCJKjp-Regular.otf が更新される。
     Godotで一度 `--headless --import --quit` を実行してインポートし直すこと。
"""

import argparse
import glob
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEST_FONT = REPO_ROOT / "assets" / "fonts" / "NotoSansCJKjp-Regular.otf"

# ゲーム内容以外に、将来のデータ編集で使われそうな文字域を広めに確保しておく。
EXTRA_UNICODE_RANGES = (
	"U+0020-007E,"  # 基本ラテン文字(半角英数記号)
	"U+2010-2027,U+2030,U+2212,"  # 各種ダッシュ/引用符/パーセントなどの記号
	"U+3000-303F,"  # CJKの記号・句読点(、。「」など)
	"U+3040-309F,"  # ひらがな全域
	"U+30A0-30FF,"  # カタカナ全域
	"U+FF00-FFEF"  # 半角/全角形(全角英数、半角カナなど)
)


def collect_content_chars() -> set[str]:
	chars: set[str] = set()

	def walk(obj) -> None:
		if isinstance(obj, dict):
			for v in obj.values():
				walk(v)
		elif isinstance(obj, list):
			for v in obj:
				walk(v)
		elif isinstance(obj, str):
			chars.update(obj)

	for path in glob.glob(str(REPO_ROOT / "data" / "*.json")):
		with open(path, encoding="utf-8") as f:
			walk(json.load(f))

	for path in glob.glob(str(REPO_ROOT / "scripts" / "*.gd")):
		src = Path(path).read_text(encoding="utf-8")
		for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', src):
			chars.update(m.group(1))

	return chars


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument(
		"--source",
		required=True,
		help="フル収録版 NotoSansCJKjp-Regular.otf へのパス",
	)
	args = parser.parse_args()

	chars = collect_content_chars()
	print(f"content characters: {len(chars)}")

	text_file = REPO_ROOT / "tools" / "_font_subset_chars.txt"
	text_file.write_text("".join(sorted(chars)), encoding="utf-8")

	cmd = [
		sys.executable,
		"-m",
		"fontTools.subset",
		args.source,
		f"--output-file={DEST_FONT}",
		f"--text-file={text_file}",
		f"--unicodes={EXTRA_UNICODE_RANGES}",
		"--glyph-names",
		"--symbol-cmap",
		"--legacy-cmap",
		"--notdef-glyph",
		"--notdef-outline",
		"--recommended-glyphs",
		"--name-IDs=*",
		"--name-legacy",
		"--name-languages=*",
		"--layout-features=*",
	]
	subprocess.run(cmd, check=True)
	text_file.unlink(missing_ok=True)

	print(f"wrote {DEST_FONT} ({DEST_FONT.stat().st_size:,} bytes)")
	print("Godotで `godot --headless --import --quit` を実行して再インポートしてください。")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
