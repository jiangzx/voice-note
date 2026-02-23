# 快记账 Logo & Splash 规范

与 App 亮白极简主题一致，体现「语音记账 + 手动记账」，企业级观感。

## 色彩

| 用途 | 色值 | 说明 |
|------|------|------|
| Splash/启动屏背景 | `#FFFFFF` 或 `#FAFAFA` | 与 `AppColors.backgroundPrimary` 一致 |
| Logo/图标主色 | `#1677FF` | `AppColors.brandPrimary` |
| 辅助文案（若有） | `#1D2129` / `#4E5969` | 对比度 ≥4.5:1 |

不再使用 `#009688`（Teal）。

## Logo 与 App 图标概念

- **语义**：快（速度/效率）、记账（账本/列表/数字）、可选语音（麦克风/声波）。
- **风格**：极简、几何、白底 + 品牌蓝，无渐变；小尺寸可辨。
- **规格**
  - **App 图标**：1024×1024px，无透明（iOS）；图形保持在 Android 12 中心 66% 安全区内。
  - **Splash 中心图**：透明底 PNG，1x 约 288–432px 或 2x 约 576–864px。

## Splash 布局（企业级 LaunchImage）

- 画布 864×1024：上方 864×864 为 logo（对勾 + **缩短的**三条横线，不侵入文案区），下方白区为文案。
- **文案**：「AI 懂你说的，记账更轻松」48pt、#1D2129，置于 logo 下方白区垂直居中，吸睛且不压线。
- 三条横线长度为 logo 内容区宽度的 50%，不穿过/越过文案区域。
- Flutter 启动后 `SplashOverlay` 与原生 splash 衔接；Android 12+ 同图作前景、白底。

## 资产路径

- App 图标主图：`assets/icon/app_icon.png`
- Splash 中心图：`assets/splash/logo.png`（含文案「AI 懂你说的，记账更轻松」时尺寸为 864×1024）

**生成带文案的 splash 图**（在项目根 `voice-note-client` 下执行）：
1. `dart run tool/generate_icons.dart` — 生成基础 logo（864×864 图形）
2. `python3 -m venv tool/.venv && tool/.venv/bin/pip install -r tool/requirements.txt` — 仅首次需创建 venv 并安装 Pillow
3. `tool/.venv/bin/python tool/generate_splash_with_text.py` — 在 logo 上叠加文案并输出为 `assets/splash/logo.png`（864×1024）

替换上述文件后执行：

- `dart run flutter_launcher_icons`
- `dart run flutter_native_splash:create`

**注意**：
- `flutter_native_splash:create` 会覆盖 `android/.../drawable/launch_background.xml`（及 drawable-v21），恢复为使用 `@drawable/background` 位图。若需保持纯白背景且不依赖插件生成的 background 图，需再次将首层改为 `<shape><solid android:color="#FFFFFF"/></shape>`。
- 若出现「第一帧仍是旧启动屏、然后才出现新启动屏」：
  1. 确保已用新 logo 重新生成原生资源：**`dart run flutter_native_splash:create`**（会更新 iOS LaunchImage.imageset 与 Android drawable）。
  2. **`flutter clean`**，再 **`cd ios && xcodebuild clean -workspace Runner.xcworkspace -scheme Runner`**。
  3. **iOS 必做**：清 Xcode 构建缓存——打开 Xcode → Product → Clean Build Folder (Shift+Cmd+K)；再在终端执行 **`rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*`**（会删掉所有 Runner 的 DerivedData，若有多项目请只删与本项目对应的那一项）。
  4. 真机/模拟器上**卸载应用**，然后 **`flutter run`** 重新安装。
  5. 若仍为旧图：**重启设备或模拟器**（iOS 有时会缓存启动图），再安装运行一次。也可使用 **`sh tool/clean_splash_cache.sh`** 一键执行步骤 1–3 与 DerivedData 清理。

## 检查清单

- [ ] 无 emoji 作图标
- [ ] Splash 与 App 内主题色系一致
- [ ] 浅色背景对比度 ≥4.5:1
- [ ] 图标在 48dp/96dp 可辨；Android 12 安全区满足
- [ ] iOS 图标无透明（remove_alpha_ios 已开）
