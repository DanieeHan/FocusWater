# FocusWater

把每一段专注，积累成一瓶清澈的水。

FocusWater 是使用 SwiftUI 开发的专注记录应用，支持 iPhone、iPad、macOS 和 Mac Catalyst。数据由 SwiftData 保存在本地，可选择通过私有 CloudKit 数据库同步。

目前处于发布前开发阶段。GitHub 源码发布和 App Store 上架是两个独立步骤；真机 iCloud、多设备冲突和旧数据库迁移仍需验证。

## 功能

- **专注**：水瓶进度、开始/暂停计时、补记时间，保留不足一分钟的计时余量。
- **收藏**：已完成水瓶及对应记录。
- **记录**：周趋势、连续专注天数、热力图、搜索、编辑、删除和 CSV 导出。
- **设置**：目标、语言、外观、iCloud 偏好、JSON 备份与合并恢复。
- 保存失败时保留输入和计时状态；数据库无法打开时提供重试、诊断导出和备份后重建。
- 支持简体中文、英文、深浅色和动态字体。

## 开发环境

- Xcode 16 或更新版本；此前完整验证使用 Xcode 26.6。
- iOS / iPadOS 17+，macOS 14+。
- 不依赖第三方 Swift 包。

直接打开 `FocusWater.xcodeproj`，选择 `FocusWater` scheme 和模拟器即可开发。真机和 iCloud 测试需要配置自己的开发团队、Bundle ID 和 CloudKit 容器。默认标识为 `com.hanzibo.FocusWater` 和 `iCloud.com.hanzibo.FocusWater`。

## 构建与测试

以下命令假定 Xcode 安装在 `/Applications/Xcode.app`，并已完成首次启动及许可确认：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild build \
  -project FocusWater.xcodeproj \
  -scheme FocusWater \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -showdestinations \
  -project FocusWater.xcodeproj \
  -scheme FocusWater

# 将 SIMULATOR_UUID 替换为上一条命令列出的 iOS 模拟器 ID。
xcodebuild test \
  -project FocusWater.xcodeproj \
  -scheme FocusWater \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  CODE_SIGNING_ALLOWED=NO
```

此前 23 项自动化测试已通过，覆盖计时恢复、重复保存、写入回滚、备份校验、数据库恢复及诊断脱敏等。本次 GitHub 准备时，本机更新后的 Xcode 27 尚未确认许可，未重新运行构建或测试。

## 数据与隐私

应用没有开发者后端、广告、第三方分析 SDK 或通知权限请求。可选 iCloud 同步使用用户 Apple ID 对应的私有数据库；开关在下次启动时生效。CSV 和 JSON 导出包含可读备注，请妥善保管。

请勿在 issue、截图或提交中附带个人记录、数据库、备份、账户信息或签名文件。隐私政策仍是[待完善的草稿](docs/PRIVACY_POLICY_TEMPLATE.md)，上架前需要填写联系信息并公开托管。

## 项目结构

```text
FocusWater/
  Models/          数据模型、计时状态、备份格式
  ViewModels/      计时、数据写入、统计与同步状态
  Views/           专注、收藏、记录、设置页面
  Resources/       应用图标和隐私清单
  AppStoreCoordinator.swift  数据容器启动与恢复
FocusWaterTests/   回归测试与故障注入测试
docs/             开发记录、隐私草稿及上架资料
```

`generate_project.py` 是历史生成器，不能保留当前完整项目配置。日常开发直接编辑已有 Xcode 项目。

历史营销截图保留在本地，不纳入首次源码提交；其界面需要更新后再用于商店发布。应用图标包含在仓库中。

## 发布资料

- [优化记录与验证边界](docs/OPTIMIZATION_2026-09.md)
- [App Store 上架清单](docs/APP_STORE_LAUNCH_CHECKLIST.md)
- [GitHub 发布准备](docs/GITHUB_RELEASE_PREPARATION.md)

许可证尚未选择，本次准备不添加默认开源许可证。

## English

FocusWater is a native SwiftUI focus tracker that turns focused minutes into bottles of water. It supports iPhone, iPad, macOS, and Mac Catalyst, with local SwiftData persistence and optional private CloudKit synchronization. This repository is a pre-release development snapshot.

## Features

- Manual focus logging and a built-in timer
- Bottle progress, overflow handling, and an archive
- Weekly statistics, streaks, and a three-month heatmap
- Session editing, deletion, and CSV export
- Recoverable timer state, partial-minute retention, and duplicate-save protection
- Versioned JSON backup/merge restore and a recoverable database error screen
- Per-device iCloud preference (applies on next launch) and transfer-event status
- Accessible, scrollable layouts; searchable full session history
- Simplified Chinese and English
- System, light, and dark appearance modes

Before App Store submission, set the development team, verify the final bundle identifier and CloudKit container, and publish the privacy policy in `docs/PRIVACY_POLICY_TEMPLATE.md` at a public URL.

See `docs/OPTIMIZATION_2026-09.md` for implementation boundaries and remaining release verification. Screenshot/demo mode now uses an isolated in-memory store. JSON exports contain readable notes and should be kept in a trusted location.
