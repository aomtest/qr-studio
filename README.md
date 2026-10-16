# QR Studio — 本地二维码生成器（Flutter / Material 3 Expressive）

粘贴内容即时生成二维码，纯本地运行，无任何网络请求。Windows 桌面版（Material 3 Expressive 风格）。

## 为什么用 GitHub Actions 构建

Flutter 的 Windows 桌面目标**必须**由 MSVC + Windows SDK 在 Windows 主机上构建（不支持 Linux/交叉编译），而本机环境存在三个坑：

1. 新版 Flutter SDK 的 `.pub-preload-cache` 预载机制在本机流式解压失败并陷入死循环；
2. 沙箱对 `reg.exe` 的黑名单导致 flutter 的 VS/SDK 探测崩溃；
3. 平台注入的代理环境变量与 dart 的网络栈交互异常。

云端 runner 环境干净（自带 VS 2022 + Windows SDK），**完全绕开这些坑**，本机只需 `git push`，不需要安装 Flutter。

## 目录结构

```
qr_flutter/
├── lib/main.dart                          # 全部应用代码（界面 + 二维码绘制）
├── pubspec.yaml                           # 依赖：qr、file_selector
├── assets/app_icon.ico                    # 应用图标（CI 复制进 runner 资源）
├── .github/workflows/build-windows.yml    # 云端构建流水线
└── .gitignore
```

CI 会自动生成 `windows/` 平台脚手架（不在仓库里），因此仓库很干净。

## 使用步骤

### 1. 在 GitHub 建一个空仓库

例如 `qr-studio`（私有公开都行，Actions 有免费额度）。

### 2. 推送代码

```bash
cd qr_flutter
git init
git add .
git commit -m "QR Studio: Material 3 Expressive 二维码生成器"
git branch -M main
git remote add origin https://github.com/<你的用户名>/qr-studio.git
git push -u origin main
```

### 3. 等待云端构建

推送后自动触发（也可在仓库 **Actions → Build Windows Release → Run workflow** 手动触发）。
首次约 5–10 分钟（含 Flutter SDK 下载与 C++ 编译，后续有缓存会快很多）。

### 4. 下载成品

**Actions → 打开最新跑批 → 页面底部 Artifacts → 下载 `QRStudio-Windows`**，解压后得到：

```
QRStudio.exe          ← 主程序（双击运行）
flutter_windows.dll   ← 运行时依赖
app.ico
data/                 ← 应用资源（必须与 exe 同目录）
```

把整个目录一起拷走即可在任何 Win10/11 上运行（WebView2 不需要，Flutter 自带渲染引擎）。

## 功能

- 粘贴/输入即时生成（中文、emoji、URL 全支持）
- 纠错等级 L / M / Q / H
- 模块样式：**圆点**（M3E 风格，三个定位角为圆角环 + 圆角内心）或 **方块**
- 导出尺寸 240 / 320 / 400 / 560
- **保存 PNG**（原生另存为对话框，按 3 倍像素密度导出）
- 深浅色主题（跟随系统 + 手动切换）
- 实时 meta 信息：QR 版本 / 模块数 / UTF-8 字节数
- 超长内容友好报错

## 本地构建（备用，可选）

需要 Flutter SDK ≥ 3.5 + Visual Studio 2022（含"使用 C++ 的桌面开发"工作负载）：

```bash
flutter create --platforms=windows --project-name qr_studio --org dev.qrstudio .
flutter pub get
flutter build windows --release
```
产物在 `build/windows/x64/runner/Release/`。

## 说明

构建目标为 Flutter stable 通道（当前 3.47.7）。若要锁死版本，把 workflow 里的
`channel: stable` 换成 `flutter-version: '3.47.7'`。
