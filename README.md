# mac-setup

新 Mac 一键装软件。

先登录 App Store，然后：

```bash
git clone https://github.com/dslmd/mac-setup && cd mac-setup
./setup.sh --dry-run   # 只看要装什么
./setup.sh             # 真装
```

装过的会跳过，装不上的不中断，最后统一列出来，可以重跑。

要增删软件，改 `setup.sh` 开头的三个列表：`CASKS`（Homebrew）、`MAS_APPS`（App Store）、`MANUAL`（只能手动装的）。
