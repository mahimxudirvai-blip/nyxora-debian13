# rdp-public — Full Debian 13 GNOME desktop on Fly.io
# Debian 13 "Trixie" + FULL GNOME desktop (task-gnome-desktop, all stock
# apps) + xrdp + SSH. Windows-like full desktop, animations ON, tuned for
# low-latency RDP that feels like a local desktop.
#
# What you get:
#   - FULL GNOME desktop: Settings, Files, Terminal, Text Editor,
#     Calculator, Calendar, Clock, Videos (Totem), Music, Photos,
#     LibreOffice (Writer/Calc/Impress), Thunderbird, GNOME Software store,
#     GNOME Tweaks, desktop icons, and every other stock GNOME app
#   - GNOME animations ENABLED (dconf default enable-animations=true;
#     nothing in this image disables them)
#   - Google Chrome (.deb, baked in) + Firefox ESR (Debian apt)
#   - VLC media player
#   - RDP on 3389 (Remmina) + SSH on 22 (sshd internal 2222)
#   - Dev tools baked in: Node 22 (NodeSource), pm2, micro, git, gh,
#     fastfetch
#   - Nyxora wallpaper (/usr/share/backgrounds/nyxora.jpg) as the GNOME
#     default background for every user
#   - /data volume mounted (same as the other Nyxora servers)
#
# xrdp low-latency tuning (see the xrdp.ini / sesman.ini steps below):
#   TCP_NODELAY + keepalive, fastpath both directions, bitmap + bulk
#   compression, 32bpp full colour, sessions survive disconnects
#   (KillDisconnected=false, no idle/disconnect timeouts) so reconnecting
#   resumes the same desktop.
#
# NOTE: this image is BIG (several GB) because task-gnome-desktop installs
# the whole desktop. The first `fly deploy` build will take a while
# (20-40 min). That is normal — do not cancel it.
#
# Deploy from nyxora-host (app rdp-public already created by fly launch):
#   cd /data && git clone https://github.com/mahimxudirvai-blip/nyxora-debian13.git
#   cd nyxora-debian13
#   1. Replace ariyan and ariyan below
#   2. fly volumes create debian13_data --size 500 -r sin -a rdp-public
#   3. fly ips allocate-v4 --shared=false -a rdp-public
#   4. fly deploy -a rdp-public
#   (Do NOT deploy from /data — the fly.toml fly launch wrote there is the
#   default one, not this one. Deploy from this repo directory.)
# Then: RDP to <dedicated-ip>:3389 as user ariyan, SSH root@<dedicated-ip> -p 22.

FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive

# Base tools + SSH + RDP stack (lean: no recommends here).
# dconf-cli provides `dconf update` for the system-wide GNOME defaults.
# NOTE: trixie renamed policykit-1 to polkitd — use polkitd here.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server curl wget gnupg ca-certificates figlet sudo dconf-cli \
    xrdp xorg xorgxrdp dbus-x11 polkitd \
    && rm -rf /var/lib/apt/lists/*

# FULL GNOME desktop — WITH recommends, so the full `gnome` set comes in
# (Settings, Files, Terminal, Videos, Music, Photos, Calendar, Clock,
# Software store, desktop icons, etc). task-gnome-desktop is the Debian
# task package for the complete GNOME desktop on trixie.
RUN apt-get update && apt-get install -y \
    task-gnome-desktop \
    && rm -rf /var/lib/apt/lists/*

# Stock apps, explicit so they are present no matter what the task pulls:
# LibreOffice suite, Thunderbird mail, GNOME Software, GNOME Tweaks,
# desktop icons (Windows-like icons on the desktop), VLC, Firefox ESR.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice-writer libreoffice-calc libreoffice-impress \
    thunderbird gnome-software gnome-tweaks \
    gnome-shell-extension-desktop-icons-ng \
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

# GNOME session for RDP logins (xrdp always uses Xorg via xorgxrdp).
RUN echo "gnome-session" > /home/ariyan/.xsession \
    && chown ariyan:ariyan /home/ariyan/.xsession \
    && echo "gnome-session" > /root/.xsession

# Skip the GNOME first-login setup wizard for ariyan.
RUN mkdir -p /home/ariyan/.config \
    && echo "yes" > /home/ariyan/.config/gnome-initial-setup-done \
    && chown -R ariyan:ariyan /home/ariyan/.config

# Nyxora wallpaper as the GNOME default background (system-wide dconf
# default — shows for every user on first login, still changeable).
COPY wallpaper.jpg /usr/share/backgrounds/nyxora.jpg
RUN mkdir -p /etc/dconf/profile /etc/dconf/db/local.d \
    && printf '%s\n' \
    'user-db:user' \
    'system-db:local' \
    'system-db:site' \
    'system-db:distro' \
    > /etc/dconf/profile/user \
    && printf '%s\n' \
    '[org/gnome/desktop/interface]' \
    'enable-animations=true' \
    '' \
    '[org/gnome/desktop/background]' \
    "picture-uri='file:///usr/share/backgrounds/nyxora.jpg'" \
    "picture-uri-dark='file:///usr/share/backgrounds/nyxora.jpg'" \
    "picture-options='zoom'" \
    '' \
    '[org/gnome/desktop/screensaver]' \
    "picture-uri='file:///usr/share/backgrounds/nyxora.jpg'" \
    > /etc/dconf/db/local.d/00-nyxora \
    && dconf update

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
    '/usr/sbin/xrdp-sesman' \
    '/usr/sbin/xrdp' \
    'exec /usr/sbin/sshd -D' \
    > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

EXPOSE 2222 3389

CMD ["/usr/local/bin/start.sh"]
