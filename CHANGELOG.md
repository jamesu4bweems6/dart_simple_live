# Changelog

All notable changes to this project will be documented in this file.

Format: Each version section starts with `## x.x.x`, followed by change lines starting with `-`.

---

## 1.8.16

- feat: iOS 导航、菜单、按钮、搜索、分段切换改用真实 UIKit 控件；iOS 26 按钮使用系统 glass / prominentGlass 配置
- feat: 设置开关、步进器、滑块和输入框由 UIKit 处理，常用弹窗与选项表使用系统原生控制器
- fix: 播放器原生玻璃按钮移除叠加玻璃底板；保留直播、弹幕、二维码与复杂内容的 Flutter 渲染
- test: 增加原生导航菜单、输入同步、设置回调、sheet 返回结果与弹窗字段回归测试

## 1.8.15

- feat: 全页面统一 iOS 26 液态玻璃风格，导航栏、弹窗和播放器控制层接入原生系统材质
- feat: 统一深浅色、分组卡片、输入框与按钮样式，兼容旧版 iOS 和其他平台
- test: 增加玻璃材质触摸穿透、主题切换、小屏布局及键盘避让回归测试

## 1.8.14

- fix: 进一步修正douyu断流问题
- tips: ios和macos用户请到action更新测试或者下载上游仓库版本

## 1.8.13

- feat: 支持自定义数据目录 (data_hive_ce) #174
- fix: douyu, 需要在配置douyu参数 说明 #182
- fix: 统一关注业务逻辑，修复tag数据混乱 #178
- fix: Windows屏幕亮度重置问题 #180
- 一些数据错误和潜在问题的修复
- 一些细节调整
- 关于linux的一系列修复 @pugaizai
- tips: ios和macos用户请到action更新测试或者下载上游仓库版本

## 1.8.12

- 基于v10811的热修版本：aur 以及 部分ui修复 #173
- feat: 允许按tag排序
- feat: 自由画面尺寸功能 #156
- feat: windows NVIDIA RTX VSR @ZhaiXB
- feat: 房间专属屏蔽词和屏蔽用户
- feat: PC端小窗记忆/开屏最大化
- feat: 弹幕随屏幕尺寸放缩
- feat: 允许禁用滑动调节亮度/音量
- feat: pc端参数启动应用
- fix: huya弹幕完整性
- 一些数据错误和潜在问题的修复
- 一些细节调整
- 关于linux的一系列修复 @pugaizai
- tips: ios和macos用户请到action更新测试或者下载上游仓库版本
