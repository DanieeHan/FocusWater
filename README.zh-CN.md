# FocusWater

[English](README.md) | **简体中文**

把每一段专注，积累成一瓶清澈的水。

FocusWater 是使用 SwiftUI 开发的专注记录应用，支持 iPhone、iPad、macOS 和 Mac Catalyst。数据由 SwiftData 保存在本地，可选择通过私有 CloudKit 数据库同步。

目前处于发布前开发阶段。GitHub 源码发布和 App Store 上架是两个独立步骤；真机 iCloud、多设备冲突和旧数据库迁移仍需验证。

## 功能

- **专注**：水瓶进度、开始/暂停计时、补记时间；新计时按实际日期拆分，保留不足一分钟的余量。
- **收藏**：已完成水瓶及对应记录。
- **记录**：周趋势、连续专注天数、热力图、搜索、编辑、删除和 CSV 导出。
- **设置**：目标、语言、外观、iCloud 偏好、JSON 备份与合并恢复。
- 保存失败时保留输入和计时状态；数据库无法打开时提供重试、诊断导出和备份后重建。
- 支持简体中文、英文、深浅色和动态字体。

## 开发环境

- Xcode 16 或更新版本；此前完整验证使用 Xcode 26.6。
- iOS / iPadOS 17+，macOS 14+。
- 不依赖第三方 Swift 包。
- 独立模型测试脚本使用 `ripgrep`（`rg`）收集源码文件，需要本机已安装。

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

## 使用许可

本项目采用自定义 [FocusWater Source-Available License](LICENSE)。允许查看、学习、fork、修改源码，以及在自己的设备上私下构建使用；分享源码时必须保留许可证和版权声明。

**未经作者书面许可，禁止将原版或修改版发布、上架、出售或分发为 App，包括免费分发、TestFlight 外部测试、安装包下载和对外托管服务。改名、换图标或修改代码不解除这一限制。**

这是带有 App 分发限制的源码公开项目。完整许可条款以 `LICENSE` 为准。

## 项目演示

水瓶跨天累计，每日统计按记录日期计算；产品规则、两分钟演示和技术讲解见 [演示指南](docs/DEMO.md)。

### 2026-10-04 本地改进验证

独立计时检查（`sh scripts/test-timer-accounting.sh`）通过 12 个回归场景与 1,000 个时长守恒案例；生产 Swift 源码通过 macOS Release/DEBUG、iOS Simulator DEBUG 类型检查。通过独立 macOS 测试脚本实际运行全部 33 项 XCTest（含跨日、暂停恢复、失败重试、余秒快照与历史水瓶用例），0 失败；iOS 模拟器 XCTest 尚未运行。本轮未进行签名构建、真机或 CloudKit 验收。

实际模型回归可运行 `sh scripts/test-model-macos.sh`（需本机 Xcode 编译器和 SDK）；脚本使用临时构建目录及隔离的内存或临时磁盘数据库，不启动 App。

### 2026-10-05 跟进验收

已修复文档中的 `sh` 调用入口，必要时自动转入 Bash。macOS XCTest 共 35 项通过，新增“删除最新瓶后的回退”及“临时磁盘数据库重新打开后保留日期、计时凭据和余秒”验证。独立计时检查再次通过 12 个场景及 1,000 个守恒案例；生产源码的 iOS Simulator DEBUG 类型检查也通过。磁盘测试使用当前 schema，不代表历史版本数据库升级已通过。详见[剩余验收步骤](docs/VALIDATION_2026-10-05.md)。
