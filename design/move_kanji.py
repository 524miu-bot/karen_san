# 「忙」を右上から左上へ動かす。右上は周りの色で埋め、円の枠を描き直す。
# karen_busy_original.webp を icon_src.png（RGB）にしてから動かすと icon_new.png ができる
# （これを karen_busy.png にした）。numpy と opencv-python が要る。
import cv2
import numpy as np

src = cv2.imread("icon_src.png")
h, w = src.shape[:2]

# 赤い文字（右上の範囲だけ）
b, g, r = [src[:, :, i].astype(int) for i in range(3)]
red = ((r > 140) & (g < 100) & (b < 80)).astype(np.uint8)
area = np.zeros_like(red)
area[30:420, 630:1010] = 1
red &= area
red &= ((r - g) > 90).astype(np.uint8)
# 大きなかたまり（文字の線）だけ残す。髪の赤っぽい点は落とす
n, lab, stats, _ = cv2.connectedComponentsWithStats(red)
red = np.isin(lab, [i for i in range(1, n) if stats[i, cv2.CC_STAT_AREA] > 300]).astype(np.uint8)
ys, xs = np.nonzero(red)
print("glyph bbox", xs.min(), xs.max(), ys.min(), ys.max())

def disk(n):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * n + 1, 2 * n + 1))

# 白いふち込みのシール部分と、消す範囲
sticker = cv2.dilate(red, disk(14))
hole = cv2.dilate(red, disk(19))

# 円の枠（紺色）の中心と半径を、文字から離れた所の紺の点で求める
navy = (b > 70) & (b < 140) & (r < 70) & (g < 90)
navy &= hole == 0
ny, nx = np.nonzero(navy)
A = np.c_[2 * nx, 2 * ny, np.ones_like(nx)]
cx, cy, c = np.linalg.lstsq(A, nx**2 + ny**2, rcond=None)[0]
rad = np.sqrt(c + cx**2 + cy**2)
d = np.hypot(nx - cx, ny - cy)
keep = np.abs(d - rad) < 30
A, nx2, ny2 = A[keep], nx[keep], ny[keep]
cx, cy, c = np.linalg.lstsq(A, nx2**2 + ny2**2, rcond=None)[0]
rad = np.sqrt(c + cx**2 + cy**2)
d = np.hypot(nx2 - cx, ny2 - cy)
inner, outer = np.percentile(d, 3), np.percentile(d, 97)
navy_color = np.median(src[ny2, nx2], axis=0)
print("circle", cx, cy, rad, inner, outer, navy_color)

# 中を周りの色で埋める（枠の紺がにじまないよう、枠と外側は中の背景色にしてから）
yy, xx = np.mgrid[0:h, 0:w]
dist = np.hypot(xx - cx, yy - cy)
tmp = src.copy()
near = (dist > inner - 40) & (dist < inner - 8) & (hole == 0) & (yy < 450) & (xx > 600)
bg = np.median(src[near], axis=0)
tmp[dist > inner - 3] = bg
# 集中線などの黒い線が、埋めた所に伸びてしみにならないように（髪のある左側は残す）
dark = src.astype(int).sum(axis=2) < 450
around = cv2.dilate(hole, disk(10)).astype(bool) & (xx > 770)
tmp[dark & around] = bg
out = cv2.inpaint(tmp, hole * 255, 9, cv2.INPAINT_TELEA)
out[(dist > inner - 3) & (hole == 0)] = src[(dist > inner - 3) & (hole == 0)]

# 消した範囲の、円の外は白・枠は紺に戻す
hm = hole.astype(bool)
out[hm & (dist > outer + 1)] = (255, 255, 255)
ring = hm & (dist >= inner) & (dist <= outer)
out[ring] = navy_color
# 枠のふちをなめらかに
edge = hm & (np.abs(dist - inner) < 1.5) | hm & (np.abs(dist - outer) < 1.5)
blur = cv2.GaussianBlur(out, (3, 3), 0)
out[edge] = blur[edge]

# 文字シールを左上へ（左右で同じだけ余白をとる）
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
nx0 = w - 1 - x1
dx = nx0 - x0
alpha = cv2.GaussianBlur(sticker.astype(np.float32), (5, 5), 0)
M = np.float32([[1, 0, dx], [0, 1, 0]])
moved = cv2.warpAffine(src, M, (w, h))
alpha = cv2.warpAffine(alpha, M, (w, h))[:, :, None]
out = (moved * alpha + out * (1 - alpha)).astype(np.uint8)

cv2.imwrite("icon_new.png", out)
cv2.imwrite("tr_after.png", out[40:420, 620:1024])
cv2.imwrite("tl_after.png", out[40:420, 0:404])
