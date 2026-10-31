#!/usr/bin/env python3
"""يهيّئ ios/ (المولَّد بـ flutter create) لصحتي النفسية: الاسم، الصلاحيات، Sign in with Apple، منصة 15، الأيقونة. آمن لإعادة التشغيل."""
import pathlib, plistlib, re
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parent.parent
r = ROOT / 'ios' / 'Runner'
with open(r / 'Info.plist', 'rb') as f: info = plistlib.load(f)
info['CFBundleDisplayName'] = 'صحتي النفسية'
info['ITSAppUsesNonExemptEncryption'] = False
info['NSCameraUsageDescription'] = 'يُستخدم الكاميرا لجلسات الفيديو مع المعالج.'
info['NSMicrophoneUsageDescription'] = 'يُستخدم الميكروفون لجلسات الفيديو مع المعالج.'
info['NSPhotoLibraryUsageDescription'] = 'لاختيار صورة الشهادة أو الرخصة عند تقديم ملف المعالج.'
with open(r / 'Info.plist', 'wb') as f: plistlib.dump(info, f)
with open(r / 'Runner.entitlements', 'wb') as f: plistlib.dump({'com.apple.developer.applesignin': ['Default']}, f)
proj = ROOT / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'
proj.write_text(re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', proj.read_text()))
pod = ROOT / 'ios' / 'Podfile'
if pod.exists(): pod.write_text(re.sub(r"^#?\s*platform :ios, '[\d.]+'", "platform :ios, '15.0'", pod.read_text(), 1, re.M))
# الأيقونة: شعار اللوتس على خلفية بيضاء (iOS يرفض الشفافية)
logo = Image.open(ROOT / 'assets' / 'logo.png').convert('RGBA')
ic = Image.new('RGBA', (1024, 1024), (255, 255, 255, 255)); w = int(1024 * .72); h = int(logo.height * w / logo.width)
ic.alpha_composite(logo.resize((w, h), Image.LANCZOS), ((1024 - w) // 2, (1024 - h) // 2)); ic = ic.convert('RGB')
d = r / 'Assets.xcassets' / 'AppIcon.appiconset'
import json
for e in json.loads((d / 'Contents.json').read_text())['images']:
    sz = float(e['size'].split('x')[0]) * int(e['scale'].rstrip('x')); ic.resize((int(sz), int(sz)), Image.LANCZOS).save(d / e['filename'])
print('ios prepared')
