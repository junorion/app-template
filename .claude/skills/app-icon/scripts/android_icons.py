"""전체 아이콘·앞면 아이콘 PNG(512)에서 안드로이드 런처 리소스를 만든다. android_icons.sh 가 부른다.
   인자: <전체 512 PNG> <앞면 512 PNG(투명 바탕)> <res 폴더> <바탕색 #RRGGBB> <상태바 아이콘 이름>
   - mipmap-*/ic_launcher.png (48dp, 적응형을 모르는 옛 런처용)
   - mipmap-*/ic_launcher_foreground.png (108dp, 적응형 앞면)
   - mipmap-*/ic_launcher_monochrome.png (108dp, Android 13 테마 아이콘 — 앞면 그림만 흰 단색)
   - drawable-*/<상태바 이름>.png (24dp, 알림 작은 아이콘 — 전체 그림을 흰 단색)
   - mipmap-anydpi-v26/ic_launcher.xml, drawable/ic_launcher_background.xml"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_resize import read_png, write_png

full, fg, res, bg, stat = sys.argv[1:6]
BG = tuple(int(bg.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4))
DPI = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

def resize(rows, w, n):
    """면적 평균 축소 (RGBA, 미리 곱한 알파로 평균해 가장자리가 하얗게 번지지 않게)"""
    out = []
    for y in range(n):
        y0, y1 = y * w / n, (y + 1) * w / n
        row = []
        for x in range(n):
            x0, x1 = x * w / n, (x + 1) * w / n
            acc = [0.0] * 4; tot = 0.0
            for sy in range(int(y0), min(w, int(y1 + 0.999))):
                wy = min(y1, sy + 1) - max(y0, sy)
                for sx in range(int(x0), min(w, int(x1 + 0.999))):
                    wx = min(x1, sx + 1) - max(x0, sx)
                    r, g, b, a = rows[sy][sx]; k = wx * wy; fa = a / 255 * k
                    acc[0] += r * fa; acc[1] += g * fa; acc[2] += b * fa; acc[3] += a * k; tot += k
            a = acc[3] / tot
            if a > 0:
                f = a / 255 * tot
                row.append((round(acc[0] / f), round(acc[1] / f), round(acc[2] / f), round(a)))
            else:
                row.append((0, 0, 0, 0))
        out.append(row)
    return out

def rgba(rows):
    return [[p if len(p) == 4 else (*p, 255) for p in r] for r in rows]

def ink(r, g, b):
    """바탕색과 뚜렷이 다른 픽셀(그림)인가 — 단색 아이콘에 남길 부분"""
    return abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2]) > 120

def save(rows, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    write_png(path, rows)

W, _, F = read_png(full); F = rgba(F)
_, _, G = read_png(fg); G = rgba(G)
M = [[(255, 255, 255, a if ink(r, g, b) else 0) for r, g, b, a in row] for row in G]
S = [[(255, 255, 255, 255 if a > 0 and ink(r, g, b) else 0) for r, g, b, a in row] for row in F]
for d, k in DPI.items():
    save(resize(F, W, round(48 * k)), f'{res}/mipmap-{d}/ic_launcher.png')
    save(resize(G, W, round(108 * k)), f'{res}/mipmap-{d}/ic_launcher_foreground.png')
    save(resize(M, W, round(108 * k)), f'{res}/mipmap-{d}/ic_launcher_monochrome.png')
    save(resize(S, W, round(24 * k)), f'{res}/drawable-{d}/{stat}.png')

os.makedirs(f'{res}/mipmap-anydpi-v26', exist_ok=True)
open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <!-- 안드로이드 13 테마 아이콘 -->
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
''')
os.makedirs(f'{res}/drawable', exist_ok=True)
open(f'{res}/drawable/ic_launcher_background.xml', 'w').write(f'''<?xml version="1.0" encoding="utf-8"?>
<!-- 적응형 아이콘 바탕. 앞면·단색은 mipmap-*/ic_launcher_foreground·monochrome.png (app-icon 의 android_icons.sh) -->
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#FF{bg.lstrip('#').upper()}"/>
</shape>
''')
print(f'{res}: 런처·적응형 앞면·단색·상태바({stat}) 아이콘, 바탕 {bg}')
