# 使用 GitHub Actions 构建 iOS

工作流：`.github/workflows/build_ios.yml`，名称 **Build iOS IPA**。

在自己的 GitHub Fork 中启用 Actions，然后推送 `codex/` 开头的分支。修改客户端、核心库或此工作流时会自动构建，使用推送分支的代码。工作流进入仓库默认分支后，也可以在 Actions 页面使用 **Run workflow** 手动选择分支构建。

构建会安装项目指定的 Flutter SDK、Rust iOS 编译目标，运行关注列表回归测试，再编译 iOS Release 应用。无需配置 Android 密钥、Firebase Secrets 或 Apple 签名证书。

运行成功后，在该次运行页面的 **Artifacts** 下载 `Slive-iOS-unsigned-运行编号`，解压得到 `Slive-unsigned.ipa`。产物保留 14 天。

此 IPA 未签名，安装到 iPhone 前需要另行签名；它不能直接用于 TestFlight 或 App Store 发布。

命令行查看构建：

```powershell
gh run list --repo 你的用户名/dart_simple_live --workflow build_ios.yml
gh run view 运行编号 --repo 你的用户名/dart_simple_live --log-failed
gh run download 运行编号 --repo 你的用户名/dart_simple_live
```
