# rdp-public — Full Debian 13 XFCE desktop on Fly.io
# Debian 13 "Trixie" + FULL XFCE desktop (task-xfce-desktop, all stock
# apps) + xrdp + SSH. Windows-like full desktop, tuned for low-latency
# RDP that feels like a local desktop. XFCE is the fastest desktop for
# RDP: no 3D compositing needed (xfwm4 runs fine on software rendering),
# so it stays fast and stable where GNOME Shell crashes.
#
# What you get:
#   - FULL XFCE desktop: Settings Manager, Thunar file manager, XFCE
#     Terminal, Mousepad text editor, Ristretto image viewer, Parole
#     media player, desktop icons, panel with application menu, and
#     every other stock XFCE app
#   - Google Chrome (.deb, baked in) + Firefox ESR (Debian apt) —
#     Chrome is the DEFAULT browser (update-alternatives + MIME
#     defaults + XFCE Preferred Applications, all set at image level)
#   - VLC media player
#   - Full LibreOffice (Writer, Calc, Impress, Draw, Math, Base),
#     Thunderbird — plus the Linux Mint XFCE app set: GIMP,
#     xfce4-screenshooter (Print key), Evince, File Roller,
#     GNOME Calculator, Synaptic, Timeshift, Catfish
#   - RDP on 3389 (Remmina) + SSH on 22 (sshd internal 2222)
#   - Dev tools baked in: Node 22 (NodeSource), pm2, micro, git, gh,
#     fastfetch
#   - Nyxora wallpaper (/usr/share/backgrounds/nyxora.jpg) as the XFCE
#     default background for every user (xfconf system default)
#   - /data volume mounted (same as the other Nyxora servers)
#
# NOTE: this is Debian XFCE carrying the Linux Mint XFCE app set — NOT
# Linux Mint itself. Mint packages are Ubuntu-based and cannot install
# on Debian/Fly. Mint-only tools (mintinstall, mintupdate, mintmenu,
# mint-themes, xreader) are not in Debian and are NOT included.
#
# xrdp low-latency tuning (see the xrdp.ini / sesman.ini steps below):
#   TCP_NODELAY + keepalive, fastpath both directions, bitmap + bulk
#   compression, 32bpp full colour, sessions survive disconnects
#   (KillDisconnected=false, no idle/disconnect timeouts) so reconnecting
#   resumes the same desktop.
#
# NOTE: this image is BIG (several GB) because LibreOffice + Chrome +
# the full desktop are baked in. The first `fly deploy` build takes a
# while (20-40 min). That is normal — do not cancel it. (XFCE itself
# is far lighter than the GNOME build it replaces.)
#
# Deploy from nyxora-host (app rdp-public already created, volume +
# dedicated IP already exist; this is a redeploy of the same app):
#   cd /data && git clone https://github.com/mahimxudirvai-blip/nyxora-debian13.git
#   cd nyxora-debian13
#   fly deploy -a rdp-public
#   (Do NOT deploy from /data — the fly.toml fly launch wrote there is the
#   default one, not this one. Deploy from this repo directory.)
#   Passwords are already set in this file (root + ariyan, both "ariyan",
#   per the user's instruction). The repo is PUBLIC, so change both
#   passwords with `passwd` after the first login.
# Then: RDP to <dedicated-ip>:3389 as user ariyan, SSH root@<dedicated-ip> -p 22.

FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive

# Base tools + SSH + RDP stack (lean: no recommends here).
# NOTE: trixie renamed policykit-1 to polkitd — use polkitd here.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server curl wget gnupg ca-certificates figlet sudo \
    xrdp xorg xorgxrdp dbus-x11 polkitd \
    && rm -rf /var/lib/apt/lists/*

# FULL XFCE desktop — WITH recommends, so the full `xfce4` set comes in
# (Thunar, Terminal, Mousepad, Ristretto, Parole, Settings Manager,
# panel, desktop icons, etc). task-xfce-desktop is the Debian task
# package for the complete XFCE desktop on trixie. (It also pulls
# lightdm, which is never started — no systemd in this container;
# xrdp is the only login path.)
RUN apt-get update && apt-get install -y \
    task-xfce-desktop \
    && rm -rf /var/lib/apt/lists/*

# Stock apps, explicit so they are present no matter what the task pulls:
# Full LibreOffice (the `libreoffice` metapackage = all 6 apps: Writer,
# Calc, Impress, Draw, Math, Base) + the Linux Mint XFCE app set:
# GIMP, xfce4-screenshooter (Print key), Evince (document viewer),
# File Roller (archives), GNOME Calculator, Synaptic (package manager),
# Timeshift (system restore), Catfish (file search). Thunderbird, VLC,
# Firefox ESR as before.
# NOTE on the Print key: no custom keyboard-shortcuts XML is written —
# libxfce4ui-common (pulled in by the XFCE session) already ships the
# upstream defaults file /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
# xfce4-keyboard-shortcuts.xml, which binds Print to
# xfce4-screenshooter (Alt+Print = window, Shift+Print = region).
# Writing a partial replacement XML would shadow that file and wipe
# the other default shortcuts (Alt+F1/F2/F3, Ctrl+Alt+T, ...), so the
# upstream file is left exactly as shipped.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice \
    gimp xfce4-screenshooter evince file-roller gnome-calculator \
    synaptic timeshift catfish \
    thunderbird \
    vlc firefox-esr \
    && rm -rf /var/lib/apt/lists/*

# Google Chrome in the image (baked-in .deb from Google).
RUN apt-get update && cd /tmp \
    && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm -f google-chrome-stable_current_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# Node 22 (NodeSource — Debian 13 ships Node 20 in main) + pm2.
# Dev tools: micro, git, gh, fastfetch (all in trixie main).
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pm2 \
    && apt-get update && apt-get install -y --no-install-recommends \
    micro git gh fastfetch \
    && rm -rf /var/lib/apt/lists/* \
    && node --version && npm --version && pm2 --version

# Font cache now, so the first terminal open is not slow
RUN fc-cache -f

RUN ssh-keygen -A

RUN echo "root:ariyan" | chpasswd

RUN useradd -m -s /bin/bash ariyan \
    && echo "ariyan:ariyan" | chpasswd \
    && usermod -aG sudo ariyan

# Google Chrome as the DEFAULT browser (image-level, so first login
# already has it). Three layers — one alone does not stick:
#   1. update-alternatives: x-www-browser + gnome-www-browser at
#      priority 200, forced with --set. (Chrome's own postinst also
#      registers 200; Firefox ESR registers 70, so Chrome would win
#      anyway — the --set makes it stick regardless of install order.)
#   2. MIME defaults: mimeapps.list mapping html/xhtml/http/https to
#      google-chrome.desktop, in /etc/skel (future users) + both
#      existing users' homes. This is also what exo falls back to
#      (xdg-mime query default x-scheme-handler/http).
#   3. XFCE Preferred Applications: helpers.rc WebBrowser=google-chrome
#      (helper name from /usr/share/xfce4/helpers/google-chrome.desktop,
#      shipped by xfce4-helpers, pulled in by xfce4-settings).
RUN update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/google-chrome-stable 200 \
    && update-alternatives --set x-www-browser /usr/bin/google-chrome-stable \
    && update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/google-chrome-stable 200 \
    && update-alternatives --set gnome-www-browser /usr/bin/google-chrome-stable \
    && mkdir -p /etc/skel/.config /home/ariyan/.config /root/.config \
    && printf '%s\n' \
    '[Default Applications]' \
    'text/html=google-chrome.desktop' \
    'application/xhtml+xml=google-chrome.desktop' \
    'x-scheme-handler/http=google-chrome.desktop' \
    'x-scheme-handler/https=google-chrome.desktop' \
    > /etc/skel/.config/mimeapps.list \
    && cp /etc/skel/.config/mimeapps.list /home/ariyan/.config/mimeapps.list \
    && cp /etc/skel/.config/mimeapps.list /root/.config/mimeapps.list \
    && mkdir -p /etc/skel/.config/xfce4 /home/ariyan/.config/xfce4 /root/.config/xfce4 \
    && printf '%s\n' 'WebBrowser=google-chrome' > /etc/skel/.config/xfce4/helpers.rc \
    && cp /etc/skel/.config/xfce4/helpers.rc /home/ariyan/.config/xfce4/helpers.rc \
    && cp /etc/skel/.config/xfce4/helpers.rc /root/.config/xfce4/helpers.rc \
    && chown -R ariyan:ariyan /home/ariyan/.config

RUN printf '%s\n' \
    'Port 2222' \
    'PermitRootLogin yes' \
    'PasswordAuthentication yes' \
    'UsePAM no' \
    'UseDNS no' >> /etc/ssh/sshd_config

# xrdp LOW-LATENCY tuning (xrdp 0.10, Debian manpage xrdp.ini(5)):
#   tcp_nodelay=true   — no TCP buffering, snappier input
#   tcp_keepalive=true — dead connections are closed, not hung
#   bitmap_cache / bitmap_compression / bulk_compression — less data on
#     the wire, faster screen updates
#   max_bpp=32         — full colour (quality stays, compression does
#     the heavy lifting)
#   new_cursors=true   — hardware cursors, no cursor lag
#   use_fastpath=both  — fastpath for input AND output (default is none)
#   allow_channels / allow_multimon — clipboard, drive redirect, multi-monitor
# NOTE: the perf.* lines (wallpaper / font smoothing / desktop
# composition) are deliberately LEFT alone — the full desktop look stays.
RUN sed -i -E \
    -e 's/^[;#]?[[:space:]]*tcp_nodelay[[:space:]]*=.*/tcp_nodelay=true/' \
    -e 's/^[;#]?[[:space:]]*tcp_keepalive[[:space:]]*=.*/tcp_keepalive=true/' \
    -e 's/^[;#]?[[:space:]]*bitmap_cache[[:space:]]*=.*/bitmap_cache=true/' \
    -e 's/^[;#]?[[:space:]]*bitmap_compression[[:space:]]*=.*/bitmap_compression=true/' \
    -e 's/^[;#]?[[:space:]]*bulk_compression[[:space:]]*=.*/bulk_compression=true/' \
    -e 's/^[;#]?[[:space:]]*max_bpp[[:space:]]*=.*/max_bpp=32/' \
    -e 's/^[;#]?[[:space:]]*new_cursors[[:space:]]*=.*/new_cursors=true/' \
    -e 's/^[;#]?[[:space:]]*use_fastpath[[:space:]]*=.*/use_fastpath=both/' \
    -e 's/^[;#]?[[:space:]]*allow_channels[[:space:]]*=.*/allow_channels=true/' \
    -e 's/^[;#]?[[:space:]]*allow_multimon[[:space:]]*=.*/allow_multimon=true/' \
    /etc/xrdp/xrdp.ini

# sesman: sessions SURVIVE disconnects — reconnecting resumes the same
# desktop instead of starting a new one. No idle timeout either.
RUN sed -i -E \
    -e 's/^[;#]?[[:space:]]*KillDisconnected[[:space:]]*=.*/KillDisconnected=false/' \
    -e 's/^[;#]?[[:space:]]*DisconnectedTimeLimit[[:space:]]*=.*/DisconnectedTimeLimit=0/' \
    -e 's/^[;#]?[[:space:]]*IdleTimeLimit[[:space:]]*=.*/IdleTimeLimit=0/' \
    /etc/xrdp/sesman.ini

# XFCE session for RDP logins (xrdp always uses Xorg via xorgxrdp).
# startxfce4 (from xfce4-session) runs /etc/xdg/xfce4/xinitrc, which
# starts the session D-Bus bus (dbus-launch) and xfce4-session itself.
RUN echo "exec startxfce4" > /home/ariyan/.xsession \
    && chown ariyan:ariyan /home/ariyan/.xsession \
    && echo "exec startxfce4" > /root/.xsession

# Nyxora wallpaper as the XFCE default background for every user.
# xfconf reads system defaults from /etc/xdg/... on first login; a
# per-user ~/.config/xfce4/xfconf/... file (created when the user
# changes the wallpaper) overrides it, so this stays changeable.
# The legacy monitor0/image-path key is the hardware-independent
# fallback xfdesktop reads when no monitor-name-keyed last-image
# exists (modern last-image keys are keyed by the monitor model name,
# which is unknown for the xrdp virtual monitor). workspace0/last-image
# + image-style=5 (zoomed) are set as well, plus monitordefault as a
# second fallback.
COPY wallpaper.jpg /usr/share/backgrounds/nyxora.jpg
RUN mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml \
    && printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<channel name="xfce4-desktop" version="1.0">' \
    '  <property name="backdrop" type="empty">' \
    '    <property name="screen0" type="empty">' \
    '      <property name="monitor0" type="empty">' \
    '        <property name="image-path" type="string" value="/usr/share/backgrounds/nyxora.jpg"/>' \
    '        <property name="image-show" type="bool" value="true"/>' \
    '        <property name="workspace0" type="empty">' \
    '          <property name="last-image" type="string" value="/usr/share/backgrounds/nyxora.jpg"/>' \
    '          <property name="image-style" type="int" value="5"/>' \
    '        </property>' \
    '      </property>' \
    '      <property name="monitordefault" type="empty">' \
    '        <property name="workspace0" type="empty">' \
    '          <property name="last-image" type="string" value="/usr/share/backgrounds/nyxora.jpg"/>' \
    '          <property name="image-style" type="int" value="5"/>' \
    '        </property>' \
    '      </property>' \
    '    </property>' \
    '  </property>' \
    '</channel>' \
    > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

# Nyxora prompt: red, hides the /data prefix (base64 so a paste can't
# mangle the backslashes — same proven method as the other Nyxora servers).
RUN printf '%s' 'X19ueXhvcmFfcHMxKCkgewogIGxvY2FsIGQ9IiRQV0QiCiAgY2FzZSAiJGQiIGluCiAgICAvZGF0YSkgZD0iIiA7OwogICAgIi9kYXRhLyRVU0VSIikgZD0iIiA7OwogICAg' > /tmp/prompt.b64 && \
    printf '%s' 'Ii9kYXRhLyRVU0VSIi8qKSBkPSIke2QjL2RhdGEvJFVTRVJ9IiA7OwogICAgL2RhdGEvKikgZD0iJHtkIy9kYXRhfSIgOzsKICBlc2FjCiAgUFMxPSJcW1wwMzNbMTszMW1c' >> /tmp/prompt.b64 && \
    printf '%s' 'XU55eG9yYS1ob3N0QFx1JHtkOis6JGR9XFxcJCBcW1wwMzNbMG1cXSIKfQpQUk9NUFRfQ09NTUFORD1fX255eG9yYV9wczEK' >> /tmp/prompt.b64 && \
    base64 -d /tmp/prompt.b64 > /etc/nyxora-prompt.sh && rm /tmp/prompt.b64

RUN printf '%s\n' '[ -f /etc/nyxora-prompt.sh ] && . /etc/nyxora-prompt.sh' >> /etc/bash.bashrc \
    && printf '%s\n' '[ -f /etc/nyxora-prompt.sh ] && . /etc/nyxora-prompt.sh' >> /etc/skel/.bashrc \
    && printf '%s\n' '[ -f /etc/nyxora-prompt.sh ] && . /etc/nyxora-prompt.sh' >> /root/.bashrc \
    && printf '%s\n' '[ -f /etc/nyxora-prompt.sh ] && . /etc/nyxora-prompt.sh' >> /home/ariyan/.bashrc

# Disk tools show ONLY /data (same as the other Nyxora servers).
RUN printf '%s\n' \
    'df() { command df -h /data; }' \
    'lsblk() { command lsblk "$@" | grep -E "NAME|/data" || true; }' \
    'mount() { command mount "$@" | grep " /data " || true; }' \
    'findmnt() { command findmnt /data; }' \
    >> /etc/bash.bashrc

RUN printf '%s\n' \
    '#!/bin/bash' \
    'W=$(stty size 2>/dev/null | cut -d" " -f2); W=${W:-80}' \
    'echo -e "\033[1;91m$(figlet -c -w "$W" Nyxora)\033[0m"' \
    'echo -e "\033[1;95mBuild Clean. Deploy Bold.\033[0m"' \
    'echo -e "\033[1;97mwelcome to the Main Nyxora Server\033[0m"' \
    'echo -e "\033[1;93mYou have administrative access. Build fearlessly.\033[0m"' \
    > /etc/profile.d/nyxora-banner.sh && chmod +x /etc/profile.d/nyxora-banner.sh

# adduser-nyxora: create a user with a private /data/<user> folder (700).
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    'if [ -z "$1" ]; then echo "Usage: adduser-nyxora <username>"; exit 1; fi' \
    'U="$1"' \
    'if id "$U" >/dev/null 2>&1; then echo "User $U already exists"; exit 1; fi' \
    'useradd -m -s /bin/bash "$U"' \
    'echo "Set password for $U:"' \
    'passwd "$U"' \
    'mkdir -p "/data/$U"' \
    'chown "$U:$U" "/data/$U"' \
    'chmod 700 "/data/$U"' \
    'printf "%s\n" "cd /data/$U" >> "/home/$U/.bashrc"' \
    'chown "$U:$U" "/home/$U/.bashrc"' \
    'echo "User $U created. Private data dir: /data/$U"' \
    > /usr/local/bin/adduser-nyxora
RUN chmod +x /usr/local/bin/adduser-nyxora

RUN printf '%s\n' 'cd /data' >> /root/.bashrc \
    && printf '%s\n' 'cd /data' >> /home/ariyan/.bashrc

RUN printf '%s\n' \
    '#!/bin/bash' \
    'mkdir -p /data' \
    'chown root:root /data' \
    'chmod 755 /data' \
    'mkdir -p /var/run/xrdp' \
    'mkdir -p /run/sshd' \
    'hostname nyxora-host 2>/dev/null || true' \
    'mkdir -p /run/dbus' \
    'dbus-daemon --system --fork' \
    '/usr/sbin/xrdp-sesman' \
    '/usr/sbin/xrdp' \
    'exec /usr/sbin/sshd -D' \
    > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

EXPOSE 2222 3389

CMD ["/usr/local/bin/start.sh"]
