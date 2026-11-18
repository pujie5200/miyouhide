# 密友（MiYouHide）

只做三件事，其它什么都没有：

1. **隐藏好友**（从通讯录/会话里消失）
2. **隐藏群 / 会话**
3. **隐藏朋友圈**（对指定对象视为没有共同群）

另带：悬浮球入口 + 数字密码。

> 从 MiYou.dylib（12.8 MB、混淆过的商业微信外挂）逆向分析后**重写**。
> 我们只保留它的 hook 思路：运行时扫描所有实现目标 selector 的类，逐个 swizzle。
> 产物约 95 KB，没有第三方依赖。

## 为什么必须走 GitHub Actions 编译

本地 Windows + LLVM(ld64.lld) 编出来的 dylib 在真机上**加载即崩**，已经用探针验证：

| 测试 | 结果 |
|---|---|
| 纯 C、无 ObjC 类（WLProbe） | ✅ 正常加载，能写日志 |
| 只要带一个静态 ObjC 类（WLProbe2/3，两种 fixups 都试过） | ❌ 微信闪退，constructor 都没进 |

结论：问题在 **lld 产出的 ObjC 元数据**，不是我们的代码。所以改用 Apple 官方工具链（Xcode 的 clang + ld64 + 真 iOS SDK）编——GitHub Actions 的 `macos-14` 正好免费提供。

## 编译（3 步，无需 Mac）

1. https://github.com/new 建**私有**仓库
2. `Add file → Upload files`，把本文件夹里的 **4 项内容**拖进去（不是拖文件夹本身）：
   ```
   .github/workflows/build.yml
   build.sh
   src/   (WLCommon.h / WLSys.h / WLHook.m / WLUI.m)
   README.md
   ```
   > `.github` 是隐藏目录，网页上传也能带上去；路径必须是 `.github/workflows/build.yml`
3. 仓库 → **Actions** → `build-MiYouHide` → 约 1 分钟 → **Artifacts** 下载 `MiYouHide-dylib` → 解压得 `MiYouHide.dylib`

构建失败就把 `Build dylib` 那段日志贴出来。

## 注入

TrollFools → 微信 → 添加 `MiYouHide.dylib` → 重启微信。
（实测 TrollFools 要签名块，不能去掉 `LC_CODE_SIGNATURE`）

## 使用

1. 打开微信，约 2 秒后**左上角 (8,120)** 出现半透明「隐」按钮
2. 点它 → 首次无密码，直接进菜单：
   - 总开关
   - 隐藏好友：开 / 关
   - 隐藏群会话：开 / 关
   - 隐藏朋友圈：开 / 关
   - 编辑好友名单 / 群名单 / 朋友圈名单（逗号分隔，`wxid_xxx` / `123@chatroom`）
   - 设置密码（留空 = 不设）
   - 隐藏悬浮球（alpha 0.03，仍可点，防锁死）
3. 名单填好后打开总开关，回微信看通讯录/会话列表生效

## 日志

`/var/mobile/Containers/Data/Application/<微信容器>/Documents/MiYouHide.log`

（Filza 里按 `com.tencent.xin` 找容器；也可以看 Console 的 `[MiYouHide]`）

正常启动会看到：

```
S0: constructor (pure C)
S1: main queue alive
inspect: 4xxxx classes
  [getContactList:contactType:] <类名> enc=<类型编码>
selector getContactList:contactType: -> N impl(s)
selector GetSessionInfoList -> N impl(s)
selector hasSharedGroup -> N impl(s)
swizzle [getContactList:contactType:] -> N class(es)
hooks installed: M method(s)
S6: all done
```

`N = 0` 表示该 selector 在你的微信版本里没有实现类（不崩，只是那一路不生效）。
过滤生效时会打印 `filter hiddenContacts: 120 -> 119`。

## 已知限制

- 朋友圈目前 hook 的是 `hasSharedGroup`（共同群判断），是近似实现；要不要 hook 朋友圈数据源看实测
- 名单只能手填 wxid / 群 id（后续可做从通讯录勾选）
- hook 点依赖微信内部 selector 名字，微信大版本更新可能需要调整
