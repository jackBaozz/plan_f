# [helloworld]

> 此项目为专用于 **[SWRT](https://github.com/SWRT-dev)** 及改版梅林固件路由器的 ShadowSocksR Plus 科学上网插件。
> 现已全新升级支持 **SS、SSR、V2Ray (VMess/VLESS)、Trojan、Hysteria 2、TUIC v5、Socks5、HTTP/HTTPS** 等多种主流代理协议！

---

## 一、 版本列表速查与文件对照表

下表列出仓库发布的各个离线安装包（位于 `bin/<架构>/` 目录下），请根据路由器架构与闪存容量选择最适合的安装包：

| 安装包文件名 | 架构平台 | 版本类型 | 安装包大小 | 支持协议 | 适用机型与场景说明 |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **`helloworld_arm_full.tar.gz`** | `arm` | **完整版 (full)** | ~20 MB | **全协议支持**<br>(含 Hysteria 2, TUIC v5, Socks5, HTTP 等) | 博通 ARMv7 (2.6.36 内核) 机型，且 JFFS/U盘空间充足设备，如 `RT-AC68U`、`RT-AC1900P`、`SBRAC1900P`、`R7000`、`K3` 等 |
| **`helloworld_arm_lite.tar.gz`** | `arm` | 精简版 (lite) | ~14 MB | 基础协议<br>(SS, SSR, V2Ray, Trojan, Socks, HTTP) | 博通 ARMv7 机型，闪存空间紧张（JFFS < 30MB 且未插 U 盘）设备 |
| **`helloworld_arm64_full.tar.gz`** | `arm64` | **完整版 (full)** | ~22 MB | **全协议支持**<br>(含 Hysteria 2, TUIC v5, Socks5, HTTP 等) | 64位 ARM (aarch64) 机型，空间充足设备，如 `RT-AC86U`、`RT-AX86U`、`RT-AX88U`、`GT-AX11000`、`RM-AX6000` 等 |
| **`helloworld_arm64_lite.tar.gz`** | `arm64` | 精简版 (lite) | ~15 MB | 基础协议<br>(SS, SSR, V2Ray, Trojan, Socks, HTTP) | 64位 ARM 机型，JFFS 闪存空间较小且不需要 Hysteria/TUIC 的用户 |
| **`helloworld_armng_full.tar.gz`** | `armng` | **完整版 (full)** | ~20 MB | **全协议支持**<br>(含 Hysteria 2, TUIC v5, Socks5, HTTP 等) | 高通/MTK/博通 armv7 (带硬件FPU) 官改固件机型，空间充足设备，如 `RT-AX56U`、`TUF-AX3000`、`RT-AX82U`、`AX3600` 等 |
| **`helloworld_armng_lite.tar.gz`** | `armng` | 精简版 (lite) | ~14 MB | 基础协议<br>(SS, SSR, V2Ray, Trojan, Socks, HTTP) | armng 架构机型，闪存较小且无需 Hysteria/TUIC 的用户 |
| **`helloworld_mips_lite.tar.gz`** | `mips` | 精简版 (lite) | ~15 MB | 基础协议<br>(SS, SSR, V2Ray, Trojan, Socks, HTTP) | MIPS 大端架构机型，如华硕 `BLUECAVE`、斐讯 `K3C`（MIPS平台因资源限制仅提供 lite 版） |
| **`helloworld_mipsle_lite.tar.gz`** | `mipsle` | 精简版 (lite) | ~15 MB | 基础协议<br>(SS, SSR, V2Ray, Trojan, Socks, HTTP) | MIPS 小端架构机型，如 `RT-AC85U`、`RT-AX53U`、`RM-AC2100`、`R6800`（仅提供 lite 版） |
| `version.json.js` | 全部 | 版本清单 | < 1 KB | - | 记录各个安装包的最新版本号及 MD5 校验码 |

---

## 二、 完整版 (full) 与 精简版 (lite) 的核心区别

为兼顾不同机型的闪存（JFFS）容量，本插件编译并提供了 **完整版 (full)** 与 **精简版 (lite)** 两种规格：

### 1. 完整版 (full)
* **核心组件**：内置全部客户端二进制，包括 `xray1`、`xray2`、`hysteria` (Hysteria 2)、`tuic-client` (TUIC v5)、`chinadns-ng`、`dns2socks`、`pdnsd`、`client_linux` (KCPTun)、`websocketd`。
* **协议覆盖**：完美支持当前所有主流协议，包括 **Hysteria 2**、**TUIC v5**、**Socks5**、**HTTP/HTTPS**、VMess、VLESS（含 Reality / Vision）、Trojan、Shadowsocks、ShadowsocksR。
* **推荐选用**：JFFS 分区剩余空间大于 **30MB** 的路由器，或者路由器已插入 U 盘并启用了虚拟内存/USB JFFS 扩展。

### 2. 精简版 (lite)
* **核心组件**：保留 `xray1`、`xray2`、`chinadns-ng`、`dns2socks`、`pdnsd`、`client_linux`，精简移除了体积庞大的 `hysteria`、`tuic-client` 和 `websocketd` 独立进程文件。
* **协议覆盖**：支持 VMess、VLESS、Trojan、Shadowsocks、ShadowsocksR、Socks5、HTTP/HTTPS，**不支持 Hysteria 2 与 TUIC**。
* **推荐选用**：闪存较小（JFFS 剩余空间 < 30MB 且未插 U 盘）的老款路由器；或平时只需使用传统协议、不需要 Hysteria/TUIC 节点的用户。

> 💡 **注意**：若从完整版降级安装精简版，插件安装脚本会自动将节点列表里的 Hysteria/TUIC 节点备份到 `/jffs/softcenter/configs/helloworld/helloworld_kv.txt`，防止节点丢失；后续重新安装完整版时会自动恢复。

---

## 三、 路由器架构查看与安装指南

### 1. 架构查看方法
1. **路由器网页查看**：登录路由器管理后台，进入 **软件中心 (Softcenter)** 首页，页面右上方或系统信息处会标明当前固件架构（如 `arm`、`arm64`、`armng`、`mips` 或 `mipsle`）。
2. **SSH 命令查看**：通过 SSH 终端登录路由器，运行以下命令：
   ```sh
   dbus get softcenter_arch
   ```
   返回结果即为对应架构目录名（例如 `arm` 或 `arm64`）。

### 2. 安装步骤
1. 进入本仓库的 [`bin/`](https://github.com/jackBaozz/plan_f/tree/bzz/bin) 目录，进入您的路由器架构对应子目录（如 `bin/arm/`）。
2. 下载对应的安装包（例如 `helloworld_arm_full.tar.gz`）。
3. 登录路由器后台，进入 **“软件中心” -> “离线安装”**。
4. 选择下载好的 `.tar.gz` 压缩包上传并安装，安装完成后刷新网页即可。

---

## 四、 详细机型与平台对应列表

### [arm](https://github.com/jackBaozz/plan_f/tree/bzz/bin/arm)
> 博通（Broadcom）ARM 平台，Linux 内核为 2.6.36.4 的 32 位 armv7 架构机型。

* **华硕系列**：`RT-AC68U`、`RT-AC66U-B1`、`RT-AC1900P`、`RT-AC88U`、`RT-AC3100`、`RT-AC3200`、`RT-AC5300`
* **ARRIS 系列**：`SBRAC1900P`、`SBRAC3200P`
* **网件系列**：`R6300v2`、`R6900P`、`R7000`、`R7000P`、`R8500`
* **斐讯系列**：`K3`
* **DLINK / 领势系列**：`DIR868L`、`EA6700`
* **其他**：`XWR3100`、`XWR3150`

---

### [arm64](https://github.com/jackBaozz/plan_f/tree/bzz/bin/arm64)
> 64 位 ARM（aarch64）架构，包含博通（BCM49xx / BCM6765 等）、高通（IPQ50xx / 60xx / 807x 标准SWRT固件）、MTK（MT798x 如 Filogic 系列）机型。

* **华硕系列**：`RT-AC86U`、`GT-AC2900`、`GT-AC5300`、`RT-AX88U`、`RT-AX86U`、`RT-AX68U`、`GT-AX11000`、`GT-AXE11000`
* **网件系列**：`R7900P`、`R7960P`、`R8000P`、`RAX80`、`RAX200`
* **红米系列**：`RM-AX6000`

---

### [armng](https://github.com/jackBaozz/plan_f/tree/bzz/bin/armng)
> 带硬件 FPU 且内核运行在 armv7 架构的机型（包含博通 BCM6750/6753/6755/6756/6855、高通 IPQ40xx/50xx/60xx/80xx 官改固件、MTK MT7622/3/9 等）。

* **华硕系列**：`RT-AX55`、`RT-AX56U`、`RT-AX58U`、`TUF-AX3000`、`TUF-AX5400`、`RT-AX82U`、`RT-ACRH17`、`RT-AC2200`、`RT-AX89X`、`RT-ACRH18`、`ZENWIFI-CT8`、`ZENWIFI-XT8`、`ZENWIFI-ET8`、`ZENWIFI-XT12`、`ZENWIFI-ETJ`、`ZENWIFI-XP4`、`GS-AX3000`、`GS-AX5400`
* **网件系列**：`RAX20`、`RAX50`、`RAX70`、`RAX120`、`MR60`
* **天邑系列**：`TY6201`、`TY6202`、`TY301`、`TYAX5400`
* **小米系列**：`AX3600`
* **其他**：`360V6`、`JDCAX1800`

---

### [mips](https://github.com/jackBaozz/plan_f/tree/bzz/bin/mips)
> MIPS 大端架构机型（仅提供 lite 精简版）。

* **华硕系列**：`BLUECAVE`
* **斐讯系列**：`K3C`

---

### [mipsle](https://github.com/jackBaozz/plan_f/tree/bzz/bin/mipsle)
> MIPS 小端架构机型（如 MT7621A 系列芯片，仅提供 lite 精简版）。

* **华硕系列**：`RT-AC85U`、`RT-AC85P`、`RT-AX53U`
* **红米系列**：`RM-AC2100`
* **网件系列**：`R6700V2`、`R6800`、`R6900V2`、`AC2400`
* **其他**：`H3C-TX1801`、`JCG-Q10PRO`

---

### ⚠️ 安装与使用注意事项

1. **JFFS 闪存空间不足的解决办法**：若 JFFS 可用空间小于 30MB，建议在路由器 USB 接口插入一个格式化为 EXT4 格式的高速 U 盘作为外挂存储，以防安装时因存储写满导致插件异常。
2. **推荐浏览器**：管理后台强烈推荐使用 Chrome、Edge 或 Firefox 浏览器，以获得最佳的前端样式兼容性与交互体验。
