# Mantou (馒头)
[![GitHub Release](https://img.shields.io/github/v/release/khcrysalis/feather?include_prereleases)](https://github.com/khcrysalis/feather/releases)
[![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/khcrysalis/feather/total)](https://github.com/khcrysalis/feather/releases)
[![GitHub License](https://img.shields.io/github/license/khcrysalis/feather?color=%23C96FAD)](https://github.com/khcrysalis/feather/blob/main/LICENSE)

Mantou（馒头）是基于Feather的增强项目，允许您使用Apple开发者账号在设备上签名和安装应用，无需电脑，并支持在原生iOS系统上轻松管理应用程序。

由于iOS系统限制，可能难以确定应用是否真正安装，因此您需要自行跟踪设备上的应用。这是一个完全原生的应用，利用iOS内置功能实现所有功能！

## 特色功能

- 支持Altstore仓库
- 导入您自己的`.ipa`文件
- 签名应用时注入插件
- 无线安装应用程序（OTA）
- 支持多证书导入，便于切换
- 可配置的签名选项
- 适用于参与`ADP`(Apple Developer Program)的Apple账户
- 无跟踪、分析或任何类似功能

## 新增功能

- **资源中心**：整合网站导航和软件源管理，实现一站式资源访问
- **网站源**：根据JSON数据自动生成网站卡片，支持图片展示
- **软件源**：支持添加和管理多个软件源，方便获取第三方应用
- **WebView优化**：自适应显示各类网站，完美支持移动端浏览体验
- **本地化支持**：全中文界面，操作更加直观便捷

## 应用预览

| <p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Images/Repos.png"><source media="(prefers-color-scheme: light)" srcset="Images/Repos_L.png"><img alt="应用源." src="Images/Repos_L.png" width="200"></picture></p> | <p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Images/Store.png"><source media="(prefers-color-scheme: light)" srcset="Images/Store_L.png"><img alt="应用商店." src="Images/Store_L.png" width="200"></picture></p> | <p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Images/Library.png"><source media="(prefers-color-scheme: light)" srcset="Images/Library_L.png"><img alt="应用库." src="Images/Library_L.png" width="200"></picture></p> | <p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Images/Sign.png"><source media="(prefers-color-scheme: light)" srcset="Images/Sign_L.png"><img alt="签名." src="Images/Sign_L.png" width="200"></picture></p> |
|:--:|:--:|:--:|:--:|
| **应用源** | **应用商店** | **应用库** | **签名** |

## 构建说明

#### 最低要求

- Xcode 15
- Swift 5.9
- iOS 15

Mantou需要包含完整的服务器框架以便本地托管服务器，因此编译后总大小约为40MB。虽然这看起来有些大，但这是实现所有功能的必要组成部分。

1. 克隆仓库
    ```sh
    git clone https://github.com/[您的用户名]/Mantou
    ```

2. 编译
    ```sh
    cd Mantou
    ./build_unsigned_ipa.sh  # 构建无签名IPA文件
    ```

3. 更新
    ```sh
    git pull
    ```

使用脚本会在build目录自动创建一个未签名的IPA文件。不建议使用此方法进行调试或报告问题。提交Pull Request或报告问题时，建议您使用Xcode正确调试您的更改。

## 关于Feather

本项目基于[Feather](https://github.com/khcrysalis/feather)开发，感谢原作者的开源贡献。我们在Feather的基础上增加了资源中心、网站导航和软件源管理等功能，使应用更加实用和便捷。

## 许可证

本项目继承了Feather的GPL-3.0许可证。您可以在[这里](https://github.com/khcrysalis/Feather/blob/main/LICENSE)查看许可证的完整详情。项目选择此特定许可证是因为我们希望继续保持与Apple Developer Account相关的侧载应用的透明度。

通过为此项目做出贡献，您同意根据GPL-3.0许可证授权您的代码，确保您的工作（如所有其他贡献）保持自由访问和开放。

## Sponsors

| Thanks to all my [sponsors](https://github.com/sponsors/khcrysalis)!! |
|:-:|
| <img src="https://raw.githubusercontent.com/khcrysalis/github-sponsor-graph/main/graph.png"> |
| _**"samara is cute" - Vendicated**_ |

## Star History

<a href="https://star-history.com/#khcrysalis/feather&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=khcrysalis/feather&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=khcrysalis/feather&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=khcrysalis/feather&type=Date" />
 </picture>
</a>

## Acknowledgements

- ~~[localhost.direct](https://github.com/Upinel/localhost.direct) - localhost with public CA signed SSL certificate~~
- [*.backloop.dev](https://backloop.dev/) - localhost with public CA signed SSL certificate
- [Vapor](https://github.com/vapor/vapor) - A server-side Swift HTTP web framework.
- [Zsign](https://github.com/zhlynn/zsign) - Allowing to sign on-device, reimplimented to work on other platforms such as iOS.
- [Nuke](https://github.com/kean/Nuke) - Image caching.
- [Asspp](https://github.com/Lakr233/Asspp) - Some code for setting up the http server.
- [plistserver](https://github.com/nekohaxx/plistserver) - Hosted on https://api.palera.in

