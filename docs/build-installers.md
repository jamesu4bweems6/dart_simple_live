# Windows / Android 安装包构建

工作流：`.github/workflows/build_installers.yml`。推送 `codex/**`、`main`、`master` 分支的相关修改，或在 GitHub Actions 手动运行 **Build Windows and Android installers**，先执行应用和斗鱼协议回归，再并行构建两个平台。

在运行页面的 **Artifacts** 下载：

- `Slive-<版本>-Windows-x64`：包含安装程序 `*-setup.exe` 和便携包 `*-portable.zip`。便携包完整解压后运行 `slive.exe`。
- `Slive-<版本>-Android`：包含 `arm64-v8a`、`armeabi-v7a`、`x86_64` 和 `universal` APK。一般手机选 `arm64-v8a`，不确定时选通用包。

文件保留 30 天。版本统一读取 `simple_live_app/pubspec.yaml`。此流程上传 Actions 构建产物，不创建 Release；现有 iOS IPA 工作流继续运行。

## Android 固定签名

仓库 Settings → Secrets and variables → Actions 需要两个加密 Secrets：

- `ANDROID_KEYSTORE_BASE64`：PKCS12/JKS 签名文件的 Base64 内容，密钥别名为 `slive`。
- `ANDROID_KEYSTORE_PASSWORD`：签名文件和密钥使用相同密码。

当前 fork 已配置独立固定签名。签名备份保存在本机 `C:\Users\Administrator\.codex\signing\dart_simple_live`，没有提交到仓库。请保留备份，同一签名才能覆盖升级已安装的 APK。首次安装若与其他来源版本签名不同，需要先卸载旧版本并提前导出数据。

其他 fork 可自行生成签名：`keytool -genkeypair -keystore release.keystore -storetype PKCS12 -alias slive -keyalg RSA -keysize 2048 -validity 10000`，设置密码后将签名文件的 Base64 和密码保存为上述 Secrets。构建结束会删除 runner 上的签名文件；缺少 Secrets 时明确报错，避免生成每次签名不同的 APK。

Windows 安装程序由 Inno Setup 打包，包含完整 Flutter 运行库和资源，采用当前用户安装，不要求管理员权限。
