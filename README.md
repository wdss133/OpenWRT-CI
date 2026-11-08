# 红米 AX6 定制 OpenWrt 云编译

> 本项目是 [VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI) 的**二创定制版**：
> 只编红米 AX6（`redmi_ax6-stock`），只装自己需要的插件，每月固定编 3 次。
>
> **所有定制只新增文件、不修改上游任何文件**（唯一例外是这份 README）。
> 所以你在 GitHub 上点 **Sync fork** 拉上游更新时不会冲突，上游怎么改都不影响。
> 源码来自 [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) 的 `owrt` 分支，
> 自带 6.18 内核、PPE 硬件 QoS、router-tool、NSS WiFi 卸载。

---

## 一、相对上游改了什么

| 项目 | 上游默认 | 本项目 |
|---|---|---|
| 编译机型 | IPQ807X 平台 **18 台**全编 | **仅 1 台**：redmi_ax6-stock |
| 编译配置 | `Config/IPQ807X-WIFI-YES.txt` | 新增 `Config/AX6-WIFI-YES.txt`（不动上游文件） |
| 触发方式 | `Auto-Clean` 每天触发 5 个平台全量编译 | 新增 `CUSTOM-AX6`，**每月 10 / 20 / 月末** 北京时间 21:00 |
| 默认主题 | `vantage` | **`argon`** |
| 插件 | 上游默认清单 | **+29 个包**（见第四节） |
| 体积裁剪 | — | **砍掉 32 个包**（USB / btrfs / samba） |
| Release 保留 | 每天把 Release 全删 | **当月全留 + 最近 36 个月每月留月末**（约 3 年） |
| Release 说明 | 上游静态文案 | 自动生成：固件信息 + 两段式插件表（版本 / 上游更新日期） |
| 运行记录 | 每天全删 | 保留 3 天 |
| ccache | 每周清一次（等于每周全量重编） | 每月 1 号清 |

## 二、编译链路

```
CUSTOM-AX6.yml（每月 10 / 20 / 月末，北京时间 21:00）
  ├─ gate job：判定今天是不是 10 号 / 20 号 / 真实月末
  │            用「明天是不是 1 号」判定，自动适配 28/29/30/31 与闰年
  │            非编译日 → 后面全部跳过，几秒结束，不占 runner
  └─ build job（needs: gate）
       └─ uses: ./.github/workflows/WRT-CORE.yml      ← 上游核心，一行未改
            ├─ 读 Config/AX6-WIFI-YES.txt + Config/GENERAL.txt 拼 .config
            ├─ Scripts/Packages.sh（拉第三方包）→ source Scripts/PRIVATE.sh
            ├─ Scripts/Settings.sh（主题 / IP / WiFi）→ cat Config/PRIVATE.txt
            ├─ make defconfig → make download → make -j
            └─ 重命名产物 → softprops/action-gh-release

Custom-Clean.yml（每天 03:00）
  └─ 当月全留 + 最近 36 个月每月只留月末那份

polish job（每次编译成功后）
  └─ 下载 .manifest → 生成两段式发布说明 → gh release edit
```

上游的 `Auto-Clean` 和 `Cache-Clean` 已在本仓库的 Actions 页面**手动禁用**（这是仓库设置，不在文件里，所以 fork/sync 都不会重置）。
禁用后，5 个 `*-ALL.yml` 的 `workflow_run` 永远不会被触发，不会再有全平台编译。

## 三、产物命名

```
qualcommax-ipq807x-redmi_ax6-stock-squashfs-factory-VIKINGYFY-owrt-WIFI-YES-YY.MM.DD-HH.MM.SS.ubi
qualcommax-ipq807x-redmi_ax6-stock-squashfs-sysupgrade-VIKINGYFY-owrt-WIFI-YES-YY.MM.DD-HH.MM.SS.bin
```

| 片段 | 含义 |
|---|---|
| `qualcommax-ipq807x-redmi_ax6-stock-squashfs-factory` | 设备 + 镜像类型 |
| `VIKINGYFY` | 源码作者（`WRT_SOURCE` 第一段） |
| `owrt` | 源码分支 |
| `WIFI-YES` | 配置类型（从 `WRT_CONFIG` 名提取，所以配置文件必须保留这个后缀） |
| `YY.MM.DD-HH.MM.SS` | 北京时间编译时间 |

Release 的 tag 是 `AX6-WIFI-YES-VIKINGYFY-owrt-YY.MM.DD-HH.MM.SS`。

## 四、内置插件（新增 29 个包）

- luci-theme-argon
- luci-app-argon-config
- kmod-tun
- easytier-noweb
- luci-app-easytier
- zerotier
- luci-app-zerotier
- ddns-go
- luci-app-ddns-go
- luci-app-store
- luci-lib-taskd
- luci-lib-xterm
- taskd
- luci-app-wechatpush
- iputils-arping
- curl
- jq
- bash
- luci-lua-runtime
- luci-compat
- luci-app-passwall
- luci-app-passwall_Nftables_Transparent_Proxy
- luci-app-passwall_INCLUDE_Xray
- luci-app-passwall_INCLUDE_Geoview
- luci-app-ddns
- ddns-scripts-cloudflare
- luci-app-frpc
- luci-app-frps
- luci-app-uhttpd

### 裁剪掉的包（32 个）

AX6 没有 USB 口，且不用 btrfs / samba，全部关闭：

- kmod-fs-btrfs
- luci-app-samba4
- luci-app-homeproxy
- kmod-usb-core
- kmod-usb-common
- kmod-usb-dwc3
- kmod-usb-dwc3-qcom
- kmod-usb-xhci-hcd
- kmod-usb-ohci
- kmod-usb-uhci
- kmod-usb-net
- kmod-usb-net-asix
- kmod-usb-net-asix-ax88179
- kmod-usb-net-cdc-eem
- kmod-usb-net-cdc-ether
- kmod-usb-net-cdc-mbim
- kmod-usb-net-cdc-ncm
- kmod-usb-net-cdc-subset
- kmod-usb-net-huawei-cdc-ncm
- kmod-usb-net-ipheth
- kmod-usb-net-rndis
- kmod-usb-net-rtl8150
- kmod-usb-net-rtl8152
- kmod-usb-net-sierrawireless
- kmod-usb-serial
- kmod-usb-serial-qualcomm
- kmod-usb-serial-wwan
- kmod-usb-wdm
- kmod-usb-roles
- kmod-usb-storage
- kmod-usb-storage-extras
- kmod-usb-storage-uas

> 这些是在 `Config/PRIVATE.txt` 里用 `is not set` 覆盖上游 `Config/GENERAL.txt` 的 `=y`
> （`Settings.sh` 先 cat GENERAL 再 cat PRIVATE，后写生效）。

## 五、默认登录信息

| 项 | 值 |
|---|---|
| 地址 | `192.168.2.1` |
| 密码 | 无 |
| 主机名 | `AX6` |
| WiFi 名称 | `AX6` |
| WiFi 密码 | `12345678` |

## 六、目录结构（本项目新增的部分）

```
Custom/
  bootstrap-fork.sh     一键定制（幂等）：生成配置、装 workflow、重建 README
  install.sh            重新 fork 后从母版仓库拉取并安装（见第八节）
  packages.seed         插件清单（唯一需要日常改的文件）
  private.sh            被装成 Scripts/PRIVATE.sh：iStore 落位 / wechatpush / 服务预启用
  gen-readme.sh         生成本 README
  gen-release-body.sh   生成 Release 说明（两段式插件表）
  release-clean.sh      Release 保留策略
  test-config.sh        自检（不联网、不编译）
  workflows/
    CUSTOM-AX6.yml      编译入口（被复制到 .github/workflows/）
    Custom-Clean.yml    Release 清理入口

Config/
  AX6-WIFI-YES.txt      只含 redmi_ax6-stock 的编译配置
  PRIVATE.txt           由 packages.seed 生成，被上游 Settings.sh 自动追加

Scripts/
  PRIVATE.sh            由 Custom/private.sh 生成，被上游 Packages.sh 自动 source
```

上游预留的两个私有扩展入口，正是我们整套方案能"零修改"的原因：
`Scripts/Settings.sh` 会读 `Config/PRIVATE.txt`，`Scripts/Packages.sh` 会 source `Scripts/PRIVATE.sh`。

## 七、日常维护

### 加 / 删插件
```bash
编辑 Custom/packages.seed
bash Custom/bootstrap-fork.sh
bash Custom/test-config.sh
git add -A && git commit -m "custom: 调整插件" && git push
```

### 改编译频率
编辑 `.github/workflows/CUSTOM-AX6.yml` 的 `cron`，以及 `gate` job 里的 `case "$day"`。

### 改设备 / 主题 / IP / WiFi
- 设备：`Custom/bootstrap-fork.sh` 顶部 `DEVICE=`，或直接改 `Config/AX6-WIFI-YES.txt`
- 主题：`Custom/bootstrap-fork.sh` 顶部 `THEME=`，或改 `CUSTOM-AX6.yml` 的 `WRT_THEME`
- IP / WiFi / 主机名：`CUSTOM-AX6.yml` 的 `WRT_IP / WRT_SSID / WRT_WORD / WRT_NAME`

## 八、重新 fork 后怎么恢复（重要）

**普通 Sync fork 不会丢东西**：因为定制全是新增文件，上游没有同名文件，合并不会冲突。

**只有"删掉仓库重新 fork"才会丢**，这时：

```bash
git clone https://github.com/<你>/OpenWRT-CI.git
cd OpenWRT-CI
curl -fsSL https://raw.githubusercontent.com/wdss133/openwrt-ci-custom/main/install.sh | bash
git add -A && git commit -m "custom: 恢复定制" && git push
```

`install.sh` 会从母版仓库 `wdss133/openwrt-ci-custom` 取回 `Custom/`，
自动生成 `Config/AX6-WIFI-YES.txt`、`Config/PRIVATE.txt`、`Scripts/PRIVATE.sh`、两个 workflow，
并重建本 README。最后一步是手动禁用 `Auto-Clean` 与 `Cache-Clean`（Actions 页面点一下，或用 `gh workflow disable`）。

---

_本 README 由 `Custom/gen-readme.sh` 自动生成。要改内容请改脚本或 `Custom/packages.seed`，勿手工大改。_
