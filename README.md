# rdp-public — Full Debian 13 GNOME desktop on Fly.io

Debian 13 "Trixie" + **full GNOME desktop** (task-gnome-desktop, all stock
apps) + xrdp + SSH. A Windows-like full desktop, animations ON, tuned so
RDP feels like a local desktop — no lag.

## What is inside

- **Full GNOME desktop**: Settings, Files, Terminal, Text Editor,
  Calculator, Calendar, Clock, Videos, Music, Photos, LibreOffice
  (Writer/Calc/Impress), Thunderbird, GNOME Software store, GNOME Tweaks,
  desktop icons, and all other stock GNOME apps
- **Animations ENABLED** — `org.gnome.desktop.interface enable-animations`
  is set true in the system dconf defaults; nothing disables it
- **Nyxora wallpaper** (`wallpaper.jpg` in this folder) installed as the
  GNOME default background for every user
- **Browsers**: Google Chrome (baked-in .deb) + Firefox ESR (Debian apt)
- **VLC** media player
- **Dev tools**: Node 22 (NodeSource), pm2, micro, git, gh, fastfetch
- **xrdp low-latency tuning**: TCP_NODELAY + keepalive, fastpath both
  directions, bitmap + bulk compression, 32bpp full colour; sessions
  survive disconnects (reconnect resumes the same desktop, no idle
  timeout)
- **Nyxora pattern**: red prompt with `/data` hidden, root lands in
  `/data`, banner, disk tools show only `/data`, `adduser-nyxora` helper
- **/data** volume (500 GB) mounted, same as the other Nyxora servers

## Deploy (from nyxora-host — app `rdp-public` already created)

```bash
cd /data && git clone https://github.com/mahimxudirvai-blip/nyxora-debian13.git
cd nyxora-debian13

# 1. Replace the two password placeholders in the Dockerfile:
#    YOUR_ROOT_PASSWORD_HERE and YOUR_ARIYAN_PASSWORD_HERE
#    (use strong passwords; never commit them anywhere)

# 2. Create the 500 GB volume in sin
fly volumes create debian13_data --size 500 -r sin -a rdp-public

# 3. Allocate a dedicated IPv4 ($2/mo — RDP needs a stable public IP)
fly ips allocate-v4 --shared=false -a rdp-public

# 4. Deploy (from this repo directory — NOT from /data, where fly launch
#    left its default fly.toml)
fly deploy -a rdp-public
```

**Note:** performance machines are untested on the `mahimxudirvai-gmail-com`
org — if deploy fails with a restriction error, the fallback is the
`maisha-talukder` org (laptop Fly account).

**The first build takes 20–40 minutes** — the GNOME desktop image is
several GB. That is normal. Do not cancel it.

## Connect

- **RDP**: `<dedicated-ip>:3389` as user `ariyan` (use Remmina or any
  RDP client; pick the **Xorg** session at the xrdp login screen)
- **SSH**: `ssh root@<dedicated-ip> -p 22`

## Notes

- The desktop keeps running when you disconnect — reconnect and you are
  back in the same session with everything still open.
- For the smoothest RDP: in Remmina set quality to "Best" (the server
  is tuned for full 32bpp colour); on a slow connection, dropping the
  client to 24bpp still feels fast because of the compression tuning.
- `uname -r` on the machine still shows the Fly kernel
  (`Linux 6.12.118-fly`-style) — Fly supplies the kernel; only the
  desktop and apps are Debian.
