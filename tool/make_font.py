"""Готовит шрифт виджета: Inter, урезанный до нужных символов.

Зачем: в Archivo (был до 2026-09-16) нет кириллицы — весь русский текст
рисовался запасным шрифтом, который CanvasKit скачивает с fonts.gstatic.com.
Из РФ этот домен доступен не всегда, и текст появлялся с задержкой.

Полный Inter — около 300 КБ на начертание. Здесь остаются только латиница,
кириллица, типографика и ₽: примерно 55 КБ на начертание.

Запуск (нужен fontTools: python -m pip install fonttools):
    python tool/make_font.py
Источник — переменный Inter из репозитория Google Fonts (лицензия OFL).
"""

import urllib.request
from pathlib import Path

from fontTools import ttLib
from fontTools.subset import Options, Subsetter
from fontTools.varLib import instancer

SOURCE = (
    "https://raw.githubusercontent.com/google/fonts/main/ofl/inter/"
    "Inter%5Bopsz,wght%5D.ttf"
)
# Начертания, которые использует виджет (FontWeight.w400…w800).
WEIGHTS = (400, 600, 700, 800)
OUT_DIR = Path("assets/fonts")

RANGES = ((0x20, 0xFF), (0x400, 0x45F), (0x490, 0x491), (0x2010, 0x2027), (0x2030, 0x203A))
EXTRA = (0x20BD, 0x2116, 0x2192, 0x2190, 0x00D7, 0x2212, 0xFEFF)


def main() -> None:
    cache = Path("build/Inter-var.ttf")
    cache.parent.mkdir(parents=True, exist_ok=True)
    if not cache.exists():
        print(f"качаю {SOURCE}")
        urllib.request.urlopen(SOURCE, timeout=120)  # noqa: S310 — фиксированный адрес
        urllib.request.urlretrieve(SOURCE, cache)  # noqa: S310

    codes = {c for a, b in RANGES for c in range(a, b + 1)} | set(EXTRA)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for weight in WEIGHTS:
        font = ttLib.TTFont(cache)
        static = instancer.instantiateVariableFont(
            font, {"wght": weight, "opsz": 14}, inplace=False, updateFontNames=True
        )
        options = Options()
        options.layout_features = ["kern", "liga", "calt", "locl", "ccmp", "mark", "mkmk"]
        options.name_IDs = ["*"]
        options.name_legacy = True
        options.notdef_outline = True
        options.drop_tables += ["DSIG"]
        subsetter = Subsetter(options=options)
        subsetter.populate(unicodes=codes)
        subsetter.subset(static)
        out = OUT_DIR / f"Inter-{weight}.ttf"
        static.save(out)
        print(f"{out}: {out.stat().st_size // 1024} КБ")


if __name__ == "__main__":
    main()
