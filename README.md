# 火星文拼音输入法

一个面向 Windows 小狼毫（Weasel）的两段式火星文拼音输入方案。

你仍然使用正常拼音选字。确认完整的普通汉字后，输入法才会进入第二阶段，让你从多种火星文写法中选择最终上屏内容。这样不会因为“在/再”等同音字而选错原意。

## 主要功能

- 两段式输入：先选正常汉字，再选火星文。
- 经典整词谐音：`有没有 -> 有木有`、`这样子 -> 酱紫`、`不知道 -> 不造/布吉岛`、`悲剧 -> 杯具`。
- 六条火星文候选：前两条偏经典词组，后四条使用形近、拆字、注音、假名、韩文和符号等技法。
- 保留原文回退候选，随时可以直接输出普通汉字。
- 内置 6 套小狼毫皮肤，默认使用竖向候选列表。
- 所有转换均在本机完成，不上传输入内容。

## 安装要求

- Windows 10 或 Windows 11。
- 已安装[小狼毫 Weasel](https://rime.im/)；也可从[官方 GitHub Releases](https://github.com/rime/weasel/releases/latest)下载。
- 推荐小狼毫 0.17.4 或更新版本。

安装小狼毫时，“旧版 IME 支持”通常不需要勾选；只有旧程序无法使用输入法时再启用。

## 安装输入法

1. 点击 GitHub 页面右上角 `Code -> Download ZIP`，解压项目。
2. 在解压后的目录空白处按住 `Shift` 并点击鼠标右键，选择“在此处打开 PowerShell 窗口”。
3. 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install_weasel.ps1
```

4. 右键任务栏中的小狼毫图标，选择“重新部署”。
5. 打开小狼毫方案菜单，选择 **火星文拼音 - 两段式**。

方案菜单通常可通过 `` Ctrl + ` `` 打开；如果快捷键无效，也可以右键小狼毫托盘图标进入方案选单。

## 使用方法

1. 第一阶段照常输入拼音并选择普通汉字；需要时可以分段选词。
2. 输入栏里不再有拼音字母后，按空格确认完整原文。
3. 第二阶段从火星文候选中选择最终写法上屏。

第二阶段按 `Esc` 或退格可以返回原拼音重新选字。候选末尾始终保留一条普通原文。

候选大致分工如下：

1. 经典词组主写法，例如“有木有”“酱紫”。
2. 另一种随机词组变体。
3. 经典字符变化。
4. 至 6. 拆合字、跨文字和装饰性更强的写法。

## 更换皮肤

| 皮肤 ID | 名称 | 风格 |
|---|---|---|
| `mars_jirai` | 地雷系 | 黑粉、深玫红 |
| `mars_sweet_cool` | 甜酷 | 黑底、霓虹热粉 |
| `mars_y2k` | Y2K 千禧 | 银白、电蓝 |
| `mars_pixel` | 像素风 | 黑绿、复古终端 |
| `mars_emo_kawaii` | Emo Kawaii | 深紫黑、薰衣草粉 |
| `mars_millennium` | 千禧动漫 | 浅紫白、粉紫 |

“皮肤 ID”是换肤命令使用的参数，不是需要修改的文件名。例如像素风的 ID 是 `mars_pixel`。

### 参数是什么意思

- `-Skin`：Windows 或应用处于浅色模式时使用的皮肤。
- `-DarkSkin`：Windows 或应用处于深色模式时使用的皮肤。
- 只填写 `-Skin`：浅色和深色模式都使用同一皮肤。
- `-Layout Vertical`：候选竖排，项目默认值，推荐使用。
- `-Layout Horizontal`：候选横排，长句可能显示不全。

### 第一步：打开正确的 PowerShell 目录

1. 打开从 GitHub 下载并解压后的项目文件夹。
2. 确认当前文件夹能看到 `set_skin.ps1`、`install_weasel.ps1` 和 `rime` 文件夹。
3. 点击文件资源管理器顶部的地址栏，输入 `powershell`，然后按回车。
4. PowerShell 打开后，提示符中的路径应当是项目文件夹，而不是 `C:\Windows\System32`。

也可以手动进入项目目录。请把下面的路径换成自己的实际解压位置：

```powershell
Set-Location "C:\Users\你的用户名\Downloads\Martian-Script-IME-main"
```

可以用下面的命令确认脚本就在当前目录：

```powershell
Get-ChildItem .\set_skin.ps1
```

### 第二步：运行换肤命令

将浅色和深色模式都切换为像素风：

```powershell
powershell -ExecutionPolicy Bypass -File .\set_skin.ps1 -Skin mars_pixel
```

浅色模式使用 Y2K，深色模式使用 Emo Kawaii：

```powershell
powershell -ExecutionPolicy Bypass -File .\set_skin.ps1 -Skin mars_y2k -DarkSkin mars_emo_kawaii
```

切换为甜酷皮肤，并明确保持候选竖排：

```powershell
powershell -ExecutionPolicy Bypass -File .\set_skin.ps1 -Skin mars_sweet_cool -Layout Vertical
```

恢复项目默认搭配（浅色 Y2K、深色千禧动漫）：

```powershell
powershell -ExecutionPolicy Bypass -File .\set_skin.ps1 -Skin mars_y2k -DarkSkin mars_millennium
```

成功后会看到类似输出：

```text
Skin updated: light=mars_y2k, dark=mars_emo_kawaii, layout=Vertical
Right-click the Weasel tray icon and choose Redeploy.
```

### 第三步：让皮肤生效

1. 找到 Windows 任务栏右下角的小狼毫图标；图标被折叠时先点击 `^`。
2. 右键小狼毫图标。
3. 点击“重新部署”。
4. 等待“维护中”提示消失，再打开任意文本框测试输入法。

换肤不需要重新安装输入法。每次修改皮肤后，只需重新部署一次。

### 换肤报错处理

如果提示“找不到 `set_skin.ps1`”，说明 PowerShell 打开的目录不正确。先执行：

```powershell
Set-Location "你的项目解压路径"
Get-ChildItem .\set_skin.ps1
```

确认第二条命令能显示文件后，再运行换肤命令。如果命令运行成功但外观没有变化，通常是还没有重新部署，或者 Windows 当前启用了另一种明暗模式。

## 更新与卸载

更新项目后，重新运行 `install_weasel.ps1` 并重新部署即可。脚本会备份相关配置，并保留你已有的皮肤文件。

卸载本项目：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall_weasel.ps1
```

卸载后再执行一次小狼毫“重新部署”。

## 常见问题

**安装完成但找不到方案**

先确认安装脚本没有报错，再重新部署，并在方案菜单中勾选“火星文拼音 - 两段式”。

**重新部署一直显示维护中**

先等待正在进行的部署结束。如果长时间没有恢复，可退出小狼毫后重新启动，再执行重新部署。

**候选仍然横向显示**

重新运行换肤脚本即可恢复竖排，例如：

```powershell
powershell -ExecutionPolicy Bypass -File .\set_skin.ps1 -Skin mars_sweet_cool -Layout Vertical
```

## 项目文件

```text
README.md                 使用说明
install_weasel.ps1        安装/更新脚本
uninstall_weasel.ps1      卸载脚本
set_skin.ps1              换肤与布局脚本
rime/                     两段式输入方案、Lua 生成器和皮肤
THIRD_PARTY_NOTICES.md    第三方资料声明
```

第三方资料与鸣谢见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
