#!/bin/sh
# 彻底清理以刷新启动图（含 Xcode DerivedData）。在 voice-note-client 下执行: sh tool/clean_splash_cache.sh

set -e
cd "$(dirname "$0")/.."

echo ">>> dart run flutter_native_splash:create"
dart run flutter_native_splash:create

echo ">>> 恢复 Android launch_background 白色 shape"
python3 -c "
import pathlib
old = '''    <item>
        <bitmap android:gravity=\"fill\" android:src=\"@drawable/background\"/>
    </item>'''
new = '''    <item>
        <shape android:shape=\"rectangle\">
            <solid android:color=\"#FFFFFF\"/>
        </shape>
    </item>'''
for p in ['android/app/src/main/res/drawable/launch_background.xml', 'android/app/src/main/res/drawable-v21/launch_background.xml']:
    f = pathlib.Path(p)
    if f.exists() and old in f.read_text():
        f.write_text(f.read_text().replace(old, new, 1))
        print('  updated', p)
"

echo ">>> flutter clean"
flutter clean

echo ">>> xcodebuild clean"
cd ios && xcodebuild clean -workspace Runner.xcworkspace -scheme Runner -configuration Debug 2>/dev/null || true
cd ..

echo ">>> 清理 Xcode DerivedData (Runner-*)"
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

echo ">>> flutter pub get"
flutter pub get

echo "完成。请卸载设备上的应用后执行: flutter run"
