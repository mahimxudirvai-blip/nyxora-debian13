# rdp-public — Full Debian 13 XFCE desktop on Fly.io

Debian 13 "Trixie" + **full XFCE desktop** (task-xfce-desktop, all stock
apps) + xrdp + SSH. A Windows-like full desktop, tuned so RDP feels
like a local desktop — fast and stable.

## Why XFCE (not GNOME)

The first build used GNOME. It deployed fine, but GNOME Shell kept
crashing under xrdp ("Oh no! Something has gone wrong") — GNOME needs
3D compositing, and this machine has no GPU, so Shell falls back to
software rendering and dies. XFCE needs no 3D at all (xfwm4 runs fine
on software rendering), which is why it is the fastest and most stable
desktop for an RDP server.

## What is inside

- **Full XFCE desktop**: Settings Manager, Thunar file manager, XFCE
  Terminal, Mousepad text editor, Ristretto image viewer, Parole media
  player, desktop icons, panel with application menu, and all other
  stock XFCE apps
- **Nyxora wallpaper** (`wallpaper.jpg` in this folder) installed as the
  XFCE default background for every user (xfconf system default at
  `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml`)
- **Google Chrome is the default browser** (Firefox ESR is also installed). Set at image level in three layers — update-alternatives (x-www-browser + gnome-www-browser, priority 200), MIME defaults (mimeapps.list), and XFCE Preferred Applications (helpers.rc `WebBrowser=google-chrome`) — so it sticks from the first login.
- **VLC** media player
- **Full LibreOffice** — Writer, Calc, Impress, Draw, Math, Base (the `libreoffice` metapackage), **Thunderbird**
- **Linux Mint XFCE app set**: GIMP, xfce4-screenshooter (Print key takes a screenshot — already bound by the upstream XFCE defaults), Evince (document viewer), File Roller (archives), GNOME Calculator, Synaptic (package manager), Timeshift (system restore), Catfish (file search)
- **Dev tools**: Node 22 (NodeSource), pm2, micro, git, gh, fastfetch
- **xrdp low-latency tuning**: TCP_NODELAY + keepalive, fastpath both
  directions, bitmap + bulk compression, 32bpp full colour; sessions
  survive disconnects (reconnect resumes the same desktop, no idle
  timeout)
- **D-Bus fix**: the container has no systemd, so `start.sh` starts the
  system D-Bus daemon (`dbus-daemon --system --fork`) before xrdp —
  without it no desktop session starts at all (this fixed the original
  black screen)
- **Nyxora pattern**: red prompt with `/data` hidden, root lands in
  `/data`, banner, disk tools show only `/data`, `adduser-nyxora` helper
- **/data** volume (500 GB) mounted, same as the other Nyxora servers

## Linux Mint — honest note

This is **Debian XFCE carrying the Linux Mint XFCE app set — NOT Linux Mint itself**. Mint's own packages are built for Ubuntu and cannot install on Debian (and Fly runs Docker images, so a Mint ISO can't be installed here at all). Mint-only tools — mintinstall, mintupdate, mintmenu, mint-themes, xreader — are not in Debian and are not included. The apps above are the Debian equivalents of what Mint XFCE ships, so day-to-day it feels like a full Mint XFCE install.

## Deploy (from nyxora-host — app `rdp-public`, redeploy)

The app, the 500 GB volume (`debian13_data`) and the dedicated IPv4
already exist — this is a redeploy of the same app, not a first setup.

```bash
cd /data && git clone https://github.com/mahimxudirvai-blip/nyxora-debian13.git rdp2
cd rdp2

# Deploy (from this repo directory — NOT from /data, where fly launch
# left its default fly.toml)
fly deploy -a rdp-public
```

**Note:** performance machines WORK on the `mahimxudirvai-gmail-com`
org (machine `83dde2db792698` launched successfully on 2026-11-25) —
the earlier restriction worry did not apply here.

**The first build takes 20–40 minutes** — the image is several GB
(LibreOffice + Chrome + full desktop). That is normal. Do not cancel
it. Rebuilds are faster (most layers are cached).

**Passwords:** root and `ariyan` are both already set in the
Dockerfile (per the user's instruction). The repo is PUBLIC, so change
both passwords with `passwd` after the first login.

## Connect

- **RDP**: `<dedicated-ip>:3389` as user `ariyan` (use Remmina or any
  RDP client; pick the **Xorg** session at the xrdp login screen).
  The session runs `exec startxfce4` from `~/.xsession`.
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
- Fly machine restarts RESET the root filesystem (only the `/data`
  volume persists) — a live `sed` on the running machine never survives
  a restart. Any fix to the running system must go into the Dockerfile
  and be redeployed.
