# 随身代理路由器 · 运维手册（换服务器 / 日常排障）

> 链路结构：`你的设备 → 小路由器 → 国内中继VPS → 境外服务器 → 出墙`
> 设计原则：**每一层只认识自己的下一跳**。换任何一段，只需要改那一跳的配置，其他层不动。
>
> ⚠️ 本手册为公开模板，`<中继IP>`、`<境外IP>`、`<SS密码>` 等占位符请替换为你自己的真实值（建议把真实值保存在私人密码管理器/备忘里，不要提交到公开仓库）。

---

## 配置清单速查

| 层 | 机器 | 配置文件 | 关键内容 |
|---|---|---|---|
| 路由器 | OpenWrt 小路由（SSH 需 legacy 算法，见 SKILL.md） | `/etc/shadowsocks.json` | 中继 IP + 端口 + SS 密码 |
| 中继 | 国内 VPS（阿里云/腾讯云） | `~/.config/mihomo/config.yaml` | 境外 IP + Reality 凭证 + **SS 入站监听（8388）** + **内置 DNS（127.0.0.1:1053）** |
| 境外 | 境外 VPS | xray 服务端 | 一般不用动 |

中继上只需要**一个 mihomo 进程**：它同时干三件事——SS 入站（接路由器）、Reality 客户端（连境外）、加密 DNS（DoH 代理解析）。不再需要 gost。

---

## 场景 A：境外 IP 被墙了 / 换境外服务器（最常见）

只需改**中继**上的 mihomo 配置，一行：

```bash
ssh <中继>

# 换 IP（密钥没变的情况，比如原服务器换了 IP）：
sudo sed -i 's/server: <老境外IP>/server: <新境外IP>/' ~/.config/mihomo/config.yaml

# 如果换了整台服务器（密钥也变了）：
# 编辑同一文件，把 uuid / public-key / short-id 也换成新的

sudo systemctl restart mihomo

# 验证（应返回新服务器的 IP）：
curl -s --max-time 15 --socks5-hostname 127.0.0.1:10809 https://api.ipify.org
```

**路由器和你的手机电脑都不用动。** Reality 只认 SNI，server 写任何可达 IP 都行。

---

## 场景 B：换国内中继（一家云 → 另一家）

### 第 1 步：在新中继上部署 mihomo

照原配置抄一份 `~/.config/mihomo/config.yaml` 改 server 即可，注意这三块必须都在：

```yaml
# 1) SS 入站：接路由器的 ss-redir / ss-tunnel（老路由器只会 aes-256-cfb）
listeners:
- name: ss-in
  type: shadowsocks
  port: 8388
  listen: 0.0.0.0
  cipher: aes-256-cfb
  password: <SS密码>
  udp: true

# 2) 内置 DNS：路由器的 ss-tunnel 把域名查询发到这里，
#    由 mihomo 用 DoH 经代理链路解析，防污染
dns:
  enable: true
  listen: 127.0.0.1:1053
  ipv6: false
  respect-rules: true
  proxy-server-nameserver:
  - 223.5.5.5
  nameserver:
  - https://1.1.1.1/dns-query
  - https://8.8.8.8/dns-query

# 3) Reality 客户端（proxies / proxy-groups / rules）照抄原配置
```

⚠️ **不要把 223.5.5.5 这类国内明文 DNS 加进 `nameserver`**——mihomo 并发查询所有上游，被墙域名会被抢答的污染结果带偏。隧道里走的本来就是被墙域名，纯 DoH 才对。

做成 systemd 服务（`Restart=always`），`mihomo -t -d <配置目录>` 校验后启动。

别忘了在云控制台的**安全组**放行 **TCP 和 UDP 8388**（两条规则！漏了 UDP 的表现：网页能开但域名解析超时）。

### 第 2 步：改路由器指向新中继（一行）

```bash
ssh <路由器>   # 需要网线连上路由器，或电脑连它的 Wi-Fi

sed -i 's/"server": "<老中继IP>"/"server": "<新中继IP>"/' /etc/shadowsocks.json
killall -9 ss-redir ss-tunnel 2>/dev/null; sleep 1
/etc/init.d/shadowsocks start
/etc/init.d/dnsmasq restart   # 清 DNS 缓存，HUP 不清！
```

---

## 日常排障三板斧

```bash
# 1. 代理本体坏没坏？（在中继上测，应返回境外服务器 IP）
ssh <中继> 'curl -s --max-time 15 --socks5-hostname 127.0.0.1:10809 https://api.ipify.org'

# 2. SS 入站坏没坏？（在中继上测，也应返回境外 IP）
ssh <中继> 'ss-local -s 127.0.0.1 -p 8388 -l 11080 -k "<SS密码>" -m aes-256-cfb -b 127.0.0.1 & sleep 2; curl -s --max-time 20 --socks5-hostname 127.0.0.1:11080 https://api.ipify.org; kill %1'

# 3. 路由器坏没坏？（连上路由器后测）
wget -q -T 15 -O /dev/null http://www.gstatic.com/generate_204 && echo 代理OK
wget -q -T 8 -O /dev/null http://www.baidu.com && echo 直连OK
nslookup openai.com 127.0.0.1   # 应返回真实 IP（104.18.x / 172.64.x 等）
```

**哪一步断了修哪一段**：第 1 步挂 → 境外/凭证问题；第 2 步挂 → mihomo SS 入站问题；第 3 步挂 → 路由器问题。

**网页能开但某些域名解析不了 / 解出奇怪的 IP**（Facebook/Twitter 的 IP 基本都是污染）：
1. 先 `/etc/init.d/dnsmasq restart` 清缓存再测（`killall -HUP dnsmasq` **不清缓存**，只重读配置）
2. 检查该域名是否在 `/etc/dnsmasq.d/*.conf` 的列表里（不在就走运营商 DNS 了）
3. 检查中继 mihomo 日志里 UDP 是否走了 DIRECT——mihomo 的 SS 入站 UDP 会**绕过规则引擎直连**，所以 ss-tunnel 的目标必须是 `-L 127.0.0.1:1053`（mihomo 自己的 DNS 模块），不能是 8.8.8.8

服务状态速查：

```bash
ssh <中继> 'sudo systemctl status mihomo --no-pager | grep -E "●|Active"; ss -tlnp | grep 8388; ss -ulnp | grep -E "8388|1053"'
ssh <路由器> 'ps w | grep -E "ss-redir|ss-tunnel" | grep -v grep'
```

中继上的服务都应配 `Restart=always`；路由器建议配看门狗 cron（见 SKILL.md）。

---

## 优雅升级（可选）：用自己的域名代替写死 IP

如果换服务器的频率变高（比如一个月一次以上），可以花几十块/年买个**自己的域名**（不是免费动态域名！），加两条 A 记录：

```
relay.你的域名    → 国内中继 IP
upstream.你的域名 → 境外服务器 IP
```

路由器和中继的配置里写域名不写 IP。以后换服务器 = 只改 DNS 记录，**所有设备零改动**。

注意：
- 免费动态域名（如 abrdns 之类）**不要用于此用途**——它的 IP 会被悄悄轮换，造成"时好时坏"的灵异故障（真实踩过）
- 域名只做 DNS 解析用，不出现在流量的 SNI 里，被针对的风险很低
- Reality 协议本身只认 SNI（serverName），配置里的 server 写 IP 还是域名都行

---

## 想换更好的路由器（可选）

WR720N 这类 4MB flash / 32MB RAM 的机器速度上限约 8-15 Mbps（CPU 太弱）。想跑满带宽 + 路由器直连 Reality（省掉中继）：

- 收一台二手 **GL.iNet MT300N-V2** 级别（128MB 内存）的机器
- 可以直接跑 xray 的 mipsle 静态二进制，省去中继接力这一环
