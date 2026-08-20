# 可选：系统中文环境与输入法

界面安装器只修改用户配置，不会自动执行需要管理员权限的系统设置。若系统本身尚未配置中文，可按需完成以下步骤。

## 系统区域设置

确认 `/etc/locale.gen` 已启用：

```text
zh_CN.UTF-8 UTF-8
```

然后在终端运行：

```bash
sudo locale-gen
sudo localectl set-locale LANG=zh_CN.UTF-8
```

注销并重新登录后检查：

```bash
localectl status
```

键盘布局可以继续使用 `us`；系统语言和物理键盘布局是两项独立设置。

## 中文字体

```bash
omarchy pkg add noto-fonts-cjk wqy-microhei wqy-zenhei
```

Noto CJK 作为主要中文字体已经足够；文泉驿字体用于兼容少数旧应用。

## 中文输入法

下面示例使用 Fcitx 5 和 Rime：

```bash
omarchy pkg add fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-rime
```

安装后打开 `fcitx5-configtool`，把 Rime 加入输入法列表。若 Fcitx 5 没有自动启动，可将系统提供的桌面启动文件复制到用户目录，并确保它没有被标记为 `Hidden=true`：

```bash
mkdir -p ~/.config/autostart
cp /etc/xdg/autostart/org.fcitx.Fcitx5.desktop ~/.config/autostart/
```

完成后注销并重新登录。不要在不理解影响的情况下同时设置多个输入法框架。

## 可选语言包

```bash
omarchy pkg add libreoffice-fresh-zh-cn man-pages-zh_cn
```

浏览器和其他应用是否提供中文界面取决于对应软件包及其自身语言设置，不属于 Omarchy Shell 汉化范围。
