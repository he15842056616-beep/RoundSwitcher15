# RoundSwitcher 15（com.max.roundswitcher15 · v1.0.0）

## ⚠️ 当前状态（请先读）
- **源码未编译、未在任何设备上测试。** 编写环境没有 Theos / iOS SDK / clang / 网络，也没有 iPhone。
- 因此**本压缩包里没有 .deb**。需要先按下面“构建”生成。
- `SBFluidSwitcherItemContainer` 是凭记忆的候选类名，**未在 iOS 16.7.16 上验证**。
  插件会在运行时检查该类是否存在，并在日志里写出实际结果。

## 构建（二选一）
**A. GitHub Actions（无需 Mac）**
1. 把本目录推送到你自己的 GitHub 仓库。
2. Actions → build-deb → Run workflow。
3. 下载 artifact 里的 `.deb`（该 workflow 同样未经验证，失败请看日志）。

**B. 本机 Theos（macOS/Linux）**
```
export THEOS=~/theos        # 需要 iOS SDK
make clean package FINALPACKAGE=1
```
产物在 `packages/`，应为 `com.max.roundswitcher15_1.0.0_iphoneos-arm64.deb`。

## 安装
1. 把 .deb 传到手机（AirDrop/Filza/SSH）。
2. Sileo → 右上角 → 导入/打开 .deb 安装，然后 Respring。
3. 或 SSH：`dpkg -i xxx.deb && sbreload`。

## 先验证，再信任（推荐流程）
1. `rs15ctl probe` → 手机 Respring。
2. 打开一次后台多任务界面。
3. `rs15ctl log` 查看日志；`/var/mobile/Library/RoundSwitcher15/dump-*.txt` 里是真实类列表和视图层级（类名、圆角、masksToBounds、阴影）。
4. 若日志出现 `NOT FOUND` 或 `no rounded candidate layer`，说明候选类/启发式不适用于你的系统，
   需要根据 dump 修改 `Tweak.x` 里的 hook 目标。
   （`rs15ctl dump` 需要 `notifyutil`，部分环境没有，此时用 probe 方式即可。）

## 关闭 / 恢复 / 卸载
- 关闭：`rs15ctl disable`（创建开关文件并 Respring，外观立即恢复）。
- 开启：`rs15ctl enable`。
- 自动保护：连续 3 次启动在 20 秒内未稳定，插件自动写入 disable 并不再 Hook。
- 卸载：Sileo → 已安装 → RoundSwitcher 15 → 移除 → Respring。只会删除 dylib、plist 和 rs15ctl，不改系统文件。
- 若无法进入 SpringBoard：SSH/Filza 删除 `/var/jb/Library/MobileSubstrate/DynamicLibraries/RoundSwitcher15.dylib`，或使用 Dopamine 安全模式。

## 工作方式与已知风险
- 只 Hook 一个类的 `layoutSubviews`，且仅修改满足以下条件的 layer：已有非零圆角、尺寸接近卡片容器。不会碰主屏图标、文件夹、Dock。
- 不会改 frame/transform/阴影，不创建新 layer。
- 若系统在 `layoutSubviews` 之后又重设 cornerRadius，则圆角可能不生效或闪回，需要换 hook 点（dump 能给出依据）。
- 系统切换动画期间的圆角动画可能与固定 15pt 有轻微跳变（未验证）。
- 带 shadowPath 的 layer 的阴影路径不会随圆角更新。

## 兼容性
| 项目 | 目标 | 验证状态 |
|---|---|---|
| iPhone 8 / A11 / arm64 | 是 | 未验证 |
| iOS 16.7.16 | 是 | 未验证 |
| Dopamine rootless + ElleKit | 是 | 未验证 |
| arm64e / iOS 15 / iOS 17 | 非目标 | 未验证 |
| 依赖 | `mobilesubstrate`（ElleKit 提供） | 若 Sileo 报依赖错误请告知 |

## 实际测试结果
| 项目 | 结果 |
|---|---|
| 编译 | 未执行 |
| Sileo 安装 | 未执行 |
| iPhone 8 实机 | 未执行 |
| 类名 / 视图层级验证 | 未执行 |
| Respring 稳定性 | 未执行 |
