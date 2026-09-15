"""Генерация иконок Android-приложений «Бронирование VR» и «VR Админка».

Рисуем программно, а не картинкой в репозитории: иконку легко пересобрать при
смене акцента, и не нужно хранить пять почти одинаковых PNG вручную.

Мотив — VR-визор из плана зала виджета (см. hall_plan.dart), на фирменном
тёмном фоне. Клиентское приложение — лаймовый акцент Effect VR: оно общее для
обоих клубов, и лайм читается на тёмном лучше изумруда. Приложение персонала —
тот же визор янтарным, чтобы на телефоне сотрудника их нельзя было перепутать.

Запуск:  python tool/make_icons.py
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFilter

# Токены темы (lib/app/theme/app_theme.dart).
BG = (8, 9, 10)            # BookingColors.bg  #08090A
ACCENT = (169, 240, 74)    # limeAccent        #A9F04A
STAFF_ACCENT = (255, 176, 46)  # янтарь — служебное приложение

# Вариант -> (акцент, source set Gradle-флейвора).
# main — ресурсы по умолчанию (client их не переопределяет),
# staff — android/app/src/staff/res перекрывает main для флейвора staff.
VARIANTS = {
    "client": (ACCENT, "main"),
    "staff": (STAFF_ACCENT, "staff"),
}

# Android mipmap: каталог -> сторона в пикселях.
MIPMAPS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Иконка для витрины RuStore (только клиентское приложение).
STORE_SIZE = 512

# Adaptive icon (Android 8+): канва 108dp, а видимой гарантированно остаётся
# только центральная «безопасная зона» 72dp — систему нельзя заставить не
# обрезать края своей маской. Поэтому рисунок занимает ~62% стороны.
FOREGROUNDS = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}
SAFE_ZONE = 0.62

SRC_DIR = os.path.join("android", "app", "src")
STORE_DIR = os.path.join("android", "store")


def draw_icon(
    size: int,
    accent: tuple[int, int, int],
    *,
    opaque: bool = True,
    scale: float = 0.60,
) -> Image.Image:
    """Рисует иконку стороной [size] цветом [accent] с запасом на сглаживание.

    [opaque] — с фирменным фоном (обычная иконка) или на прозрачном фоне
    (передний слой adaptive icon, фон там задаётся отдельно в XML).
    [scale] — ширина визора долей от стороны.
    """
    # Рисуем в 4x и уменьшаем: PIL не сглаживает фигуры, антиалиасинг получаем
    # даунсэмплингом.
    s = size * 4
    img = Image.new("RGBA", (s, s), BG + (255,) if opaque else (0, 0, 0, 0))

    # Габариты визора: широкий, слегка приплюснутый, как в плане зала.
    vw, vh = s * scale, s * scale * 0.567
    x0, y0 = (s - vw) / 2, (s - vh) / 2
    x1, y1 = x0 + vw, y0 + vh

    # Свечение — отдельным слоем: ImageDraw пишет пиксели напрямую и
    # полупрозрачную заливку не смешивает, получилось бы сплошное пятно.
    # Только на непрозрачном фоне: поверх прозрачности тот же ореол читается
    # как белёсая заливка внутри визора, а в adaptive icon фон и так тёмный.
    if opaque:
        halo = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        pad = s * 0.045
        hd.rounded_rectangle(
            [x0 - pad, y0 - pad, x1 + pad, y1 + pad],
            radius=int((vh + pad * 2) * 0.5),
            fill=accent + (38,),
        )
        halo = halo.filter(ImageFilter.GaussianBlur(s * 0.03))
        img = Image.alpha_composite(img, halo)

    d = ImageDraw.Draw(img)

    # Корпус визора — контур с круглым верхом и почти прямым низом, ровно как
    # `_visor` в hall_plan.dart (BorderRadius.vertical(top: 11, bottom: 5)).
    # Выреза «под нос» там нет, и здесь он тоже не нужен: любая фоновая фигура
    # поверх стирала бы свечение и торчала наружу «ножкой».
    # Один контур: PIL задаёт скругление одним радиусом на все углы, и попытка
    # собрать «круглый верх + прямой низ» из двух фигур даёт лишнюю линию на
    # стыке. Ровная капсула читается как визор не хуже.
    stroke = max(2, int(s * 0.05))
    d.rounded_rectangle(
        [x0, y0, x1, y1],
        radius=int(vh * 0.48),
        outline=accent + (255,),
        width=stroke,
    )

    # Две линзы внутри.
    ew, eh = vw * 0.22, vh * 0.32
    ey = y0 + (vh - eh) / 2
    for cx in (x0 + vw * 0.17, x1 - vw * 0.17 - ew):
        d.rounded_rectangle(
            [cx, ey, cx + ew, ey + eh],
            radius=int(eh * 0.5),
            fill=accent + (255,),
        )

    return img.resize((size, size), Image.LANCZOS)


def draw_foreground(size: int, accent: tuple[int, int, int]) -> Image.Image:
    """Передний слой adaptive icon: визор на прозрачном фоне.

    Рисуем сразу прозрачным, а не вырезаем фон из готовой иконки: попытка
    отделить рисунок по яркости оставляла внутри визора серую муть от
    сглаживания и свечения.

    Визор занимает [SAFE_ZONE] стороны — система обрежет канву 108dp своей
    маской до ~72dp, и всё, что шире, срежется.
    """
    return draw_icon(size, accent, opaque=False, scale=SAFE_ZONE)


def main() -> None:
    for variant, (accent, source_set) in VARIANTS.items():
        res_dir = os.path.join(SRC_DIR, source_set, "res")

        for folder, px in MIPMAPS.items():
            path = os.path.join(res_dir, folder)
            os.makedirs(path, exist_ok=True)
            draw_icon(px, accent).save(os.path.join(path, "ic_launcher.png"))
            print(f"{variant}: {folder}/ic_launcher.png  {px}x{px}")

        for folder, px in FOREGROUNDS.items():
            path = os.path.join(res_dir, folder)
            os.makedirs(path, exist_ok=True)
            draw_foreground(px, accent).save(
                os.path.join(path, "ic_launcher_foreground.png")
            )
            print(f"{variant}: {folder}/ic_launcher_foreground.png  {px}x{px}")

    os.makedirs(STORE_DIR, exist_ok=True)
    store = os.path.join(STORE_DIR, "icon-512.png")
    # Витрина не принимает прозрачность — кладём на сплошной фон.
    draw_icon(STORE_SIZE, ACCENT).convert("RGB").save(store)
    print(f"{store}  {STORE_SIZE}x{STORE_SIZE}")


if __name__ == "__main__":
    main()
