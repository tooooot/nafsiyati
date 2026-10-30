"""يولّد أيقونات الويب والأندرويد من الشعار الأساسي assets/logo.png (زهرة اللوتس) بدل أيقونة Flutter الافتراضية.
يُشغَّل في الـworkflow بعد flutter create. الخلفية بيضاء، والشعار في المنتصف بهامش."""
import os
from PIL import Image
logo = Image.open('assets/logo.png').convert('RGBA')
def icon(size, pad):
    im = Image.new('RGBA', (size, size), (255, 255, 255, 255)); w = int(size * (1 - 2 * pad)); h = int(logo.height * w / logo.width)
    im.alpha_composite(logo.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2)); return im.convert('RGB')
for name, size, pad in [('Icon-192.png', 192, .12), ('Icon-512.png', 512, .12), ('Icon-maskable-192.png', 192, .26), ('Icon-maskable-512.png', 512, .26)]:
    if os.path.isdir('web/icons'): icon(size, pad).save(f'web/icons/{name}')
if os.path.isdir('web'): icon(64, .08).save('web/favicon.png')
for d, s in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    p = f'android/app/src/main/res/mipmap-{d}'
    if os.path.isdir(p): icon(s, .1).save(f'{p}/ic_launcher.png')
print('icons ok')
