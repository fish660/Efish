<div align="center">

# Efish 英鱼 · 英语单词批量背诵软件

一款为「批量记忆」而生的桌面背单词应用（Flutter · Windows · 本地 SQLite · 离线可用）

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue.svg)](#)
[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B.svg)](#)

</div>

## 这是什么

Efish 是作者凭自己背单词的学习效率模式而自行开发的一款背单词软件。

不同于市面上「某背、某斩」等**一个一个推送单词**的模式，Efish 实行**多推送、批量记忆与学习**：一次随机抽取一批单词（10 / 20 / 30 / 50 / 自定义），先集中熟悉，再整批默写，配合间隔复习，快速扩大词汇量。

> 实际体验可与市面单词软件结合使用：**先用 Efish 批量记忆和背诵，再使用市面上的单词软件进行精细学习。**

## 功能特性

- **批量新词**：从「从未学过」的单词中随机抽取指定数量，先在熟悉页集中浏览英文 / 词性 / 中文 / 音标 / 例句，再进入「看中文默写英文」，自动判分。
- **一键标记已学会**：熟悉页每个单词末尾的 `→` 可直接标记「已学会」，计入已学习并进入复习，无需逐词默写。
- **默写测试**：题目顺序随机打乱；自动忽略大小写、首尾空格、多余空格。
- **间隔复习**：内置 `1 / 3 / 7 / 15 / 30` 天记忆曲线，到期单词自动出现；连续答对 5 次即「掌握」，答错降级、次日重来。
- **总测试**：从当前词书随机抽词，支持「看中文默写英文」「看英文默写中文」双模式。
- **错词本**：闪卡逐张回忆，翻面查看英文 / 音标 / 例句，标记认识与否；支持列表模式与清除记录。
- **每日篇章收录**：按日期记录每天学过的每一批单词，可回看任意历史日期。
- **学习日历**：打卡、每日学习数量；可点击日期**编辑学习计划**（小红点标记）；内置**节日、法定节假日、休息日、调休**显示。
- **桌宠陪伴**：会眨眼、耳朵 / 呆毛 / 鱼鳍 / 尾巴缓慢摆动的小桌宠，点击或切换页面会弹出鼓励语。
- **单词发音**：点击喇叭即可朗读（系统英文语音，完全离线）。
- **多词书**：内置《2027 考研英语红宝书》与《六级真题核心词汇》，顶部一键切换，**不同词书数据完全隔离、互不相通**；支持导入自己的 CSV / JSON 词书。
- **多主题**：海系（默认淡蓝）/ 日系（暖米），选择持久化，所有页面统一生效。
- **后续功能待开发**
## 下载与使用（无需源码）

前往右侧 **[Releases（发行版）](../../releases)** 下载最新的 `Efish.x.x.x.zip`：

1. 解压整个文件夹（不要只把 `Efish.exe` 单独拖出来）。
2. 双击 `Efish.exe` 即可启动，**无需安装、无需联网、无需浏览器**。
3. 首次启动自动创建数据库并内置词书。

## 从源码构建

### 环境要求

- Windows 10 / 11 x64
- Flutter 3.47+、Dart 3.13+（仅开发 / 构建需要，运行分发无需）

### 构建步骤

```powershell
# 国内用户建议先设置镜像
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

flutter pub get
flutter build windows --release
```

构建产物位于：

```
build\windows\x64\runner\Release\
```

> 注意：工程路径请使用纯英文，中文路径可能导致构建失败。

### 运行测试

```powershell
flutter test --concurrency=1
```

## 数据存储

- 运行时数据（学习进度、错词、计划、导入词书）保存在：

```
C:\Users\<用户名>\AppData\Roaming\Efish\words.db
```

- 删除软件文件夹不会影响学习记录；如需重置全部进度，删除上述数据库后重启即可。
- 种子词库随程序打包在 `assets/words.db`。

## 词库

| 词书 | 单词量 |
| --- | --- |
| 2027 考研英语红宝书 | 约 6500+ |
| 六级真题核心词汇 | 约 2000+ |

支持通过「导入单词」功能导入自己的词书（CSV / JSON）。

## 源码结构

```
lib/
├── main.dart            # 入口 + 主框架（侧边导航 / 顶栏词书切换 / 主题）
├── db.dart              # SQLite 打开、建表、设置
├── models.dart          # 数据模型
├── services.dart        # 业务逻辑（抽词 / 判分 / 复习 / 统计 / 篇章）
├── tts.dart             # 离线单词发音
├── lunar.dart           # 农历转换（1900-2099）
├── holidays.dart        # 节日 / 法定节假日 / 休息日服务
├── pages/               # 各功能页面
│   ├── home_page.dart
│   ├── learn_flow.dart
│   ├── quiz_page.dart
│   ├── mistakes_page.dart
│   ├── words_page.dart
│   ├── statistics_page.dart
│   ├── passages_page.dart
│   └── import_page.dart
└── widgets/
    ├── animated_pet.dart    # 动态桌宠
    └── word_widgets.dart    # 单词 / 音标 / 发音等通用组件
assets/                    # 种子数据库、桌宠部件、图标
test/                      # 自动化测试
windows/                   # Windows 桌面运行配置
```

## 技术栈

- **Flutter / Dart**（Material 3，原生桌面，无前端框架）
- **SQLite**（`sqlite3` + `sqlite3_flutter_libs`，本地持久化）
- 原生 JavaScript / React / Vue 等均未使用；不依赖网络与浏览器。

## 路线图

- [ ] 精细单词推送模式（一个一个推送的深度学习模式）
- [ ] 更多词书与词书管理
- [ ] 学习数据云同步 / 导出
- [ ] 更多主题与桌宠互动

## 反馈

有任何使用建议或问题，欢迎：

- 提交 [Issue](../../issues)
- 发送邮件至：**2460951290@qq.com**

## License

本项目基于 [MIT License](LICENSE) 开源。
