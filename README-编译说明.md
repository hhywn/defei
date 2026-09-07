# Jstudy 客户端 Spike — 无 Windows 也能编译

VCL 编译器只有 Windows 版。当前没有 Windows 机器时,优先用 **GitHub Actions 免费云编译**;
想看到界面效果时,再用 Wine 或云 Windows 服务器。

## 方案 A:GitHub Actions 云编译(0 元, 已配好)

1. 打开 <https://github.com/new> 建一个 **Private** 仓库(名字随意, 如 `delphi-client-spike`)
2. 在本目录执行(没有 git 就 `brew install git`):

   ```bash
   git init && git add -A && git commit -m "delphi spike"
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git push -u origin main
   ```

   或把整个目录拖进 GitHub 网页的 "uploading an existing file"。
3. 打开仓库的 **Actions** 页签:push 后自动开始编译,绿色 = 通过。
   红色 = 失败,点进去看错误列表,截图或复制日志回来。
4. 编译成功:Actions 该次运行页底部 **Artifacts** → 下载 `JstudyClientSpike-win32`。
   里面是 `JstudyClientSpike.exe`(Win32, 自带 VCL 库链接进 exe, 不需要额外 DLL)。

> 修改了代码再验证:`git add -A && git commit -m "fix" && git push` 即可。

## 拿到 EXE 之后(可选)在本机看界面

macOS 上跑 Windows EXE,按芯片选:

- **Intel Mac**: `brew install --cask wine-stable`,然后 `wine JstudyClientSpike.exe`
- **Apple 芯片(M1/M2/M3/M4)**:装 [Whisky](https://getwhisky.app)(免费, 基于 GPTK),
  用它建一个 Windows 环境再双击 exe

如果 Wine 里界面渲染正常,就能直接截图对照 `preview-client.html`。

## 方案 B:云 Windows 服务器(需要跑 IDE/看效果时)

- 腾讯云/阿里云「轻量应用服务器 · Windows Server」最低配约 ¥30~60/月,按量计费更便宜
- 远程桌面连上 → 装 [Delphi 12 Community](https://www.embarcadero.com/products/delphi/starter)(免费, 邮箱即可)
- 打开 `JstudyClientSpike.dpr` → `Shift+F9` 编译 → `F9` 运行,想微调字号/间距直接把截图发回来

## 常见编译报错对照

| 现象 | 原因 |
|---|---|
| `Cannot find unit Winapi.Windows` 等 | 本方案无需处理(rsvars.bat 已带库路径) |
| 中文注释乱码 | 说明文件丢了 BOM,重推已带 BOM 的版本即可 |
| `action-install` 找不到/参数报错 | 社区动作改版, 把 CI 日志发回来换新写法 |
