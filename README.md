<p align="center">
  <img src="docs/cardline-icon.png" width="96" height="96" alt="Cardline 图标">
</p>

<h1 align="center">Cardline</h1>

<p align="center"><strong>把截图挂到屏幕顶部，把临时文件放到手边。</strong></p>
<p align="center">截图晾衣绳 · 文件暂存架 · 本地图片与 PDF 工具 · 扁平清新主题</p>

Cardline 是 [jiuyang5354/snapline-windows](https://github.com/jiuyang5354/snapline-windows)（Snapline）的非官方美化版，而 Snapline 本身是 [Alejandro Buján](https://github.com/alejandrobujan) 的 [Tendedero](https://github.com/alejandrobujan/tendedero) 的非官方 Windows 实现。功能、快捷键、数据格式与 Snapline v1.5.1 一致，只替换了名称、图标和整套外观。使用独立名称和图标，不代表原作者官方版本或背书。

## 与 Snapline 的区别

- **四套扁平主题**：薄荷（默认）、天空、樱花、青柠，每套都有浅色和深色版本；设置 → 左下角"主题"切换，保存后截图栏、设置页、文件工具和暂存架同步换色。
- **绳子与夹子**：一条主题色实线取代灰色金属绳，夹子换成圆润的卡通小夹。
- **截图卡片**：去掉液态玻璃容器，改为白底圆角卡片加 2px 主题色边框，不再采样桌面背景。
- **设置页与工具窗口**：实色扁平样式，主按钮、开关、侧栏选中块都用主题色。
- **独立数据目录**：`%LOCALAPPDATA%\Cardline`，与已安装的 Snapline 互不影响，可以同时运行。
- **更新源**：指向本仓库的 `update.json`，不会收到 Snapline 原仓库的更新推送。

Snapline 的完整功能说明、常见问题和限制见 [docs/SNAPLINE-README.md](docs/SNAPLINE-README.md)（[English](docs/SNAPLINE-README.en.md)）。

## 运行与构建

支持 Windows 10 / 11，需要 .NET Framework 4.8 或更高版本；WebP 工具需要 64 位 Windows。目前尚未提供安装包，请自行构建：

```powershell
powershell -ExecutionPolicy Bypass -File windows\build.ps1
windows\bin\Cardline.exe
```

构建脚本会用系统自带的 `csc.exe` 编译，并自动下载 PdfSharp 转换组件。安装包与便携包的打包方式见 [windows/PACKAGE-README.md](windows/PACKAGE-README.md)。

## 许可与来源

Windows 实现按 [LICENSE](LICENSE) 中的 MIT 许可提供；Tendedero 的原始许可见 [UPSTREAM-LICENSE.txt](UPSTREAM-LICENSE.txt)；各部分来源与署名见 [NOTICE.md](NOTICE.md)。
