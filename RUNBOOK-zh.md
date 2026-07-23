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
| 中继 | 国内 VPS（阿里云/腾讯云） | `~/.config/mihomo/config.yaml` | 境外 IP + Reality 凭证 |
| 中继 | 同上 | `systemctl status gost-ss` | SS 接力服务（默认 8388 端口） |
| 境外 | 境外 VPS | xray 服务端 | 一般不用动 |

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

### 第 1 步：在新中继上装两个服务

```bash
ssh <新中继>

# 1) mihomo（或 xray）客户端，连境外 —— 照原配置抄一份改 server 即可
#    配置文件放 ~/.config/mihomo/config.yaml，做成 systemd 服务（Restart=always）

# 2) gost 接力（https://github.com/ginuerzh/gost/releases 下载 linux_amd64）
sudo install -m 755 gost /usr/local/bin/gost

sudo tee /etc/systemd/system/gost-ss.service << 'EOF'
[Unit]
Description=gost SS relay to mihomo
After=network.target

[Service]
ExecStart=/usr/local/bin/gost -L "ss://aes-256-cfb:<SS密码>@:8388" -F "socks5://127.0.0.1:10809"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now gost-ss mihomo
```

别忘了在云控制台的**安全组**放行 TCP 8388。

### 第 2 步：改路由器指向新中继（一行）

```bash
ssh <路由器>   # 需要网线连上路由器，或电脑连它的 Wi-Fi

sed -i 's/"server": "<老中继IP>"/"server": "<新中继IP>"/' /etc/shadowsocks.json
killall -9 ss-redir ss-tunnel 2>/dev/null; sleep 1
/etc/init.d/shadowsocks start
```

---

## 日常排障三板斧

```bash
# 1. 代理本体坏没坏？（在中继上测，应返回境外服务器 IP）
ssh <中继> 'curl -s --max-time 15 --socks5-hostname 127.0.0.1:10809 https://api.ipify.org'

# 2. SS 接力坏没坏？（在中继上测，也应返回境外 IP）
ssh <中继> 'ss-local -s 127.0.0.1 -p 8388 -l 11080 -k "<SS密码>" -m aes-256-cfb -b 127.0.0.1 & sleep 2; curl -s --max-time 20 --socks5-hostname 127.0.0.1:11080 https://api.ipify.org; kill %1'

# 3. 路由器坏没坏？（连上路由器后测）
wget -q -T 15 -O /dev/null http://www.gstatic.com/generate_204 && echo 代理OK
wget -q -T 8 -O /dev/null http://www.baidu.com && echo 直连OK
```

**哪一步断了修哪一段**：第 1 步挂 → 境外/凭证问题；第 2 步挂 → gost 问题；第 3 步挂 → 路由器问题。

服务状态速查：

```bash
ssh <中继> 'sudo systemctl status mihomo gost-ss --no-pager | grep -E "●|Active"'
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
- 可以直接跑 xray 的 mipsle 静态二进制，省去 gost 接力这一环
