# カレンさんの絵（正方形）から、アプリのアイコン一式を作る。
# 使い方: python design/make_icons.py [元の絵]   （元の絵の初期値は design/karen_busy.png）
import sys
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent.parent
src = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "design" / "karen_busy.png"
img = Image.open(src).convert("RGB")
side = min(img.size)
img = img.crop(((img.width - side) // 2, (img.height - side) // 2,
                (img.width + side) // 2, (img.height + side) // 2))


def save(im, size, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.resize((size, size), Image.LANCZOS).save(path)


# maskable（Android などで丸や角丸に切られる）は、周りを白で広げて絵が切れないようにする
pad = int(side * 0.12)
padded = Image.new("RGB", (side + pad * 2, side + pad * 2), "white")
padded.paste(img, (pad, pad))

web = root / "web"
save(img, 32, web / "favicon.png")
save(img, 180, web / "icons" / "apple-touch-icon.png")
save(img, 192, web / "icons" / "Icon-192.png")
save(img, 512, web / "icons" / "Icon-512.png")
save(padded, 192, web / "icons" / "Icon-maskable-192.png")
save(padded, 512, web / "icons" / "Icon-maskable-512.png")

# アプリの中（ログイン画面など）に出す絵
save(img, 384, root / "assets" / "branding" / "karen.png")

# iPhone 版。App Store は透明度付きを受け付けないので RGB のまま保存する
ios = root / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
for name, size in {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167, "Icon-App-1024x1024@1x.png": 1024,
}.items():
    save(img, size, ios / name)
print("done")
