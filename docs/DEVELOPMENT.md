# 开发与资源维护

所有命令均从仓库根目录执行。日常运行只需要 Flutter / Android 工具链；Node.js、Python、Chrome 和 FFmpeg 仅用于下述校验或资源再生成。

## 真机音频回归

```sh
flutter build apk --profile --target=integration_test/native_audio_test.dart
flutter drive --profile --use-application-binary=build/app/outputs/flutter-apk/app-profile.apk --driver=test_driver/integration_test.dart --target=integration_test/native_audio_test.dart --keep-app-running -d <Android设备ID>
```

使用 `.debug` 独立包名、内存存档，运行触摸、存读档、原生音频和游戏动作回归。使用 `--driver=test_driver/mobile_screenshots.dart` 可将标题、游戏和背包截图保存到`build/screenshots/`；背包截图通过测试注入道具展示样式，不代表正式进度。先构建，再通过 `--use-application-binary` 明确指定测试 APK；不要省略该参数。Flutter 3.24.5 直接从工程运行测试时，清理阶段可能依据基础 applicationId 卸载正式包，不能对已有正式进度的设备使用 `flutter test integration_test/...` 或不带预构建 APK 的 `flutter drive`。

Android 短音频切换到依赖内置的 SoundPool，并依据 WAV 实际时长复用播放器，各音符不再单独抢占音频焦点，修复 MediaPlayer 播放完成时 `prepareAsync()` 引发的闪退。后续版本调整了素材响度；SoundPool 播放路径和游戏规则保持不变。

## 对照与测试

```sh
flutter analyze
flutter test
node tool/export_data.mjs --check
node tool/verify_assets.mjs
cd reference && npm test
```

- `test/parity_test.dart`：原 JavaScript 引擎与规则的逐调用输出、完整状态、撤销历史及错误对照。覆盖全部 50 层非空格、全部主动道具、怪物数值边界及原版测试。
- `test/controller_parity_test.dart`：101 步原 store 操作，比较状态、提示、存档槽等，仅标准化已批准移除的首次键盘帮助弹窗。
- `test/services_test.dart`：长按节奏、存档快照、重载、删除、写入失败与损坏记录。
- `test/ui_test.dart`：开局、剧情、地图查看、方向键、撤销、保存/读取、系统返回；375×812、320×568、812×375 屏幕，包含安全区域及 1×/2×系统字号。
- `test/art_test.dart`：全部怪物、道具、NPC 和地图设施的新美术覆盖。

参考代码保留在 `reference/`，不参与 APK 执行。重新生成对照数据：

```sh
node tool/export_data.mjs
node tool/generate_fixtures.mjs
node tool/generate_controller_fixtures.mjs
```

音频由原 `audio.js` 的振荡器、包络及音序通过 Chrome OfflineAudioContext 导出。`node tool/render_audio.mjs` 需要本机 Google Chrome 和 FFmpeg（仅重新导出时使用）；已有 419 个 WAV 文件随源码提供，日常构建无需重新生成。

## 资源来源

- `reference/`：固定上游提交的部分源码、规则与测试，供数据导出和行为对照，不参与 Flutter 运行。
- `assets/data/game.json`：地图与数值，记录 `sourceCommit`，由 `tool/export_data.mjs` 导出。
- `assets/art/`：新版标题和透明图集；生成记录见 [PROVENANCE.txt](../assets/art/PROVENANCE.txt)。
- `assets/images/`：地图 SVG 与保留的参考图形；`python3 tool/build_tiles.py` 可重建新版地图材质。
- `assets/audio/`：预渲染音频，音序来自上游，响度由 `tool/master_audio.mjs` 调整。`FFMPEG_PATH` 和 `CHROME_PATH` 可覆盖工具位置。

图集按原实体 ID 映射，不改变游戏逻辑。保留 `pubspec.lock` 与 Gradle wrapper，避免克隆后依赖版本漂移。

## 当前验证边界

验证时间和结果见 [VERIFICATION.md](VERIFICATION.md)。1.1.2 的音量调整与 1.1.3 的首页加载修改仅构建安装，未运行完整回归；不要将历史测试记录视为当前版本全部通过。
