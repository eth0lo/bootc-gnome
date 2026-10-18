FROM quay.io/fedora/fedora-bootc:44

# FEDORA-44-GROUPS.md
#
# Expand gnome-desktop from the same Fedora 44 comps snapshot.
# The group was deleted from the group install list and contained these
# selected packages:
#
# Mandatory:
#   dconf,
#   gdm,
#   gnome-control-center,
#   gnome-initial-setup,
#   gnome-session-wayland-session,
#   gnome-settings-daemon,
#   gnome-shell,
#   gnome-software,
#   gnome-text-editor,
#   nautilus,
#   polkit,
#   ptyxis,
#   yelp.
#
# Default:
#   ModemManager,
#   NetworkManager-adsl,
#   NetworkManager-openconnect-gnome,
#   NetworkManager-openvpn-gnome,
#   NetworkManager-ppp,
#   NetworkManager-ssh-gnome,
#   NetworkManager-vpnc-gnome,
#   NetworkManager-wwan,
#   PackageKit-command-not-found,
#   PackageKit-gtk3-module,
#   adobe-source-code-pro-fonts,
#   avahi,
#   baobab,
#   decibels,
#   fprintd-pam,
#   glib-networking,
#   glycin-thumbnailer,
#   gnome-backgrounds,
#   gnome-bluetooth,
#   gnome-boxes,
#   gnome-browser-connector,
#   gnome-calculator,
#   gnome-calendar,
#   gnome-characters,
#   gnome-classic-session,
#   gnome-clocks,
#   gnome-color-manager,
#   gnome-connections,
#   gnome-contacts,
#   gnome-disk-utility,
#   gnome-epub-thumbnailer,
#   gnome-font-viewer,
#   gnome-logs,
#   gnome-maps,
#   gnome-remote-desktop,
#   gnome-system-monitor,
#   gnome-user-docs,
#   gnome-user-share,
#   gnome-weather,
#   gst-thumbnailers,
#   gvfs-afc,
#   gvfs-afp,
#   gvfs-archive,
#   gvfs-fuse,
#   gvfs-goa,
#   gvfs-gphoto2,
#   gvfs-mtp,
#   gvfs-smb,
#   librsvg2,
#   libsane-hpaio,
#   localsearch,
#   loupe,
#   mesa-dri-drivers,
#   mesa-libEGL,
#   papers,
#   papers-nautilus,
#   rygel,
#   sane-backends-drivers-scanners,
#   showtime,
#   simple-scan,
#   snapshot,
#   sushi,
#   systemd-oomd-defaults,
#   tinysparql,
#   vte-profile,
#   xdg-desktop-portal,
#   xdg-desktop-portal-gnome,
#   xdg-desktop-portal-gtk,
#   xdg-user-dirs-gtk.
#
# Omitted:
#   gnome-software and its PackageKit UI plugins
#   PackageKit-command-not-found and PackageKit-gtk3-module.
#   PackageKit-glib remains a dependency of simple-scan; it is a client library,
#   not the PackageKit system-update service.
#
# Expand multimedia from the same Fedora 44 comps snapshot.
# The group was deleted from the group install list and contained these
# selected packages:
#
# Mandatory:
#   PackageKit-gstreamer-plugin,
#   alsa-ucm,
#   alsa-utils,
#   gstreamer1-plugin-dav1d,
#   gstreamer1-plugin-libav,
#   gstreamer1-plugin-openh264,
#   gstreamer1-plugins-bad-free,
#   gstreamer1-plugins-good,
#   gstreamer1-plugins-ugly-free,
#   libva-intel-media-driver,
#   pipewire-alsa,
#   pipewire-config-raop,
#   pipewire-gstreamer,
#   pipewire-pulseaudio,
#   pipewire-utils,
#   wireplumber.
#
# Conditional:
#   gstreamer-plugins-espeak
#       (requires gstreamer; retain the condition below rather than installing it unconditionally).
#
# Omitted:
#   PackageKit-gstreamer-plugin.
RUN dnf -y --setopt=exclude_from_weak=PackageKit group install \
        # core group starts
        core \
        # base-graphical group starts
        base-graphical \
        # networkmanager-submodules group starts
        networkmanager-submodules \
        # domain-client group starts
        domain-client \
        # hardware-support group starts
        hardware-support \
        # printing group starts
        printing \
    && dnf -y --setopt=exclude_from_weak=PackageKit install \
        # Expanded gnome-desktop group package list starts
        dconf \
        gdm \
        gnome-control-center \
        gnome-initial-setup \
        gnome-session-wayland-session \
        gnome-settings-daemon \
        gnome-shell \
        gnome-text-editor \
        nautilus \
        polkit \
        ptyxis \
        yelp \
        ModemManager \
        NetworkManager-adsl \
        NetworkManager-openconnect-gnome \
        NetworkManager-openvpn-gnome \
        NetworkManager-ppp \
        NetworkManager-ssh-gnome \
        NetworkManager-vpnc-gnome \
        NetworkManager-wwan \
        adobe-source-code-pro-fonts \
        avahi \
        baobab \
        decibels \
        fprintd-pam \
        glib-networking \
        glycin-thumbnailer \
        gnome-backgrounds \
        gnome-bluetooth \
        gnome-boxes \
        gnome-browser-connector \
        gnome-calculator \
        gnome-calendar \
        gnome-characters \
        gnome-classic-session \
        gnome-clocks \
        gnome-color-manager \
        gnome-connections \
        gnome-contacts \
        gnome-disk-utility \
        gnome-epub-thumbnailer \
        gnome-font-viewer \
        gnome-logs \
        gnome-maps \
        gnome-remote-desktop \
        gnome-system-monitor \
        gnome-user-docs \
        gnome-user-share \
        gnome-weather \
        gst-thumbnailers \
        gvfs-afc \
        gvfs-afp \
        gvfs-archive \
        gvfs-fuse \
        gvfs-goa \
        gvfs-gphoto2 \
        gvfs-mtp \
        gvfs-smb \
        librsvg2 \
        libsane-hpaio \
        localsearch \
        loupe \
        mesa-dri-drivers \
        mesa-libEGL \
        papers \
        papers-nautilus \
        rygel \
        sane-backends-drivers-scanners \
        showtime \
        simple-scan \
        snapshot \
        sushi \
        systemd-oomd-defaults \
        tinysparql \
        vte-profile \
        xdg-desktop-portal \
        xdg-desktop-portal-gnome \
        xdg-desktop-portal-gtk \
        xdg-user-dirs-gtk \
        # Expanded multimedia group package list starts
        alsa-ucm \
        alsa-utils \
        gstreamer1-plugin-dav1d \
        gstreamer1-plugin-libav \
        gstreamer1-plugin-openh264 \
        gstreamer1-plugins-bad-free \
        gstreamer1-plugins-good \
        gstreamer1-plugins-ugly-free \
        libva-intel-media-driver \
        pipewire-alsa \
        pipewire-config-raop \
        pipewire-gstreamer \
        pipewire-pulseaudio \
        pipewire-utils \
        wireplumber \
        # Explicit image packages start
        authselect \
        flatpak \
        fwupd \
        glibc-langpack-en \
    && if rpm -q --quiet gstreamer; then \
        dnf -y install gstreamer-plugins-espeak; \
    fi \
    && dnf clean all

# Native Bazaar is image-managed. Use Universal Blue's Fedora 44 package,
# pin its verified stable build, verify RPM signatures, and leave the COPR
# disabled outside this transaction. No Bazaar source patches are applied.
COPY --chmod=0644 files/etc/yum.repos.d/bazaar.repo /etc/yum.repos.d/bazaar.repo
COPY --chmod=0644 files/usr/share/ublue-os/bazaar/main.yaml /usr/share/ublue-os/bazaar/main.yaml
COPY --chmod=0644 files/usr/share/ublue-os/bazaar/content.yaml /usr/share/ublue-os/bazaar/content.yaml
RUN dnf -y --enablerepo=ublue-os-packages --setopt=exclude_from_weak=PackageKit install \
        bazaar-0.9.3-4.fc44 python3-gobject-base \
    && dnf clean all

COPY --chmod=0755 files/usr/libexec/bootc-gnome-flathub /usr/libexec/bootc-gnome-flathub
COPY --chmod=0755 files/usr/libexec/bootc-gnome-flatpak-defaults /usr/libexec/bootc-gnome-flatpak-defaults
COPY --chmod=0644 files/usr/share/bootc-gnome/flatpak-defaults /usr/share/bootc-gnome/flatpak-defaults
COPY --chmod=0644 files/usr/share/bootc-gnome/flathub-runtimes.filter /usr/share/bootc-gnome/flathub-runtimes.filter
COPY --chmod=0644 files/usr/lib/systemd/system/bootc-gnome-flathub.* /usr/lib/systemd/system/
COPY --chmod=0644 files/usr/lib/systemd/system/bootc-gnome-flatpak-defaults.* /usr/lib/systemd/system/
COPY --chmod=0644 files/usr/lib/systemd/user/bootc-gnome-flathub.* /usr/lib/systemd/user/
RUN curl --fail --location --retry 3 https://dl.flathub.org/repo/flathub.flatpakrepo \
        --output /usr/share/bootc-gnome/flathub.flatpakrepo \
    && printf '%s  %s\n' \
        3371dd250e61d9e1633630073fefda153cd4426f72f4afa0c3373ae2e8fea03a \
        /usr/share/bootc-gnome/flathub.flatpakrepo | sha256sum --check \
    && systemctl disable flatpak-add-fedora-repos.service \
    && systemctl mask flatpak-add-fedora-repos.service \
    && /usr/libexec/bootc-gnome-flathub seed \
    && /usr/libexec/bootc-gnome-flatpak-defaults --seed \
    && /usr/libexec/bootc-gnome-flathub system \
    && flatpak list --system --columns=ref,active > /usr/share/bootc-gnome/flatpak-build-refs.txt \
    && systemctl enable bootc-gnome-flathub.service bootc-gnome-flathub.timer bootc-gnome-flatpak-defaults.timer \
    && systemctl --global enable bootc-gnome-flathub.service bootc-gnome-flathub.timer \
    && mv /usr/bin/bazaar-daemon /usr/libexec/bootc-gnome-bazaar-daemon
COPY --chmod=0755 files/usr/libexec/bootc-gnome-bazaar /usr/bin/bazaar-daemon

# In bootc, /home points to /var/home. Create that parent directory at boot;
# PAM/oddjob creates each user's /var/home/<user> directory on first login.
COPY --chmod=0644 files/usr/lib/tmpfiles.d/bootc-gnome-home.conf /usr/lib/tmpfiles.d/bootc-gnome-home.conf

# GNOME Initial Setup created the account but left its home directory missing.
# domain-client installs oddjob-mkhomedir; authselect adds its PAM module, and
# oddjobd creates /var/home/<user> at first login. Creating /var/home alone
# provides only the parent, so enable the PAM feature and service as well.
RUN install -d -m 0755 /var/home \
    && authselect enable-feature with-mkhomedir \
    && systemctl enable oddjobd.service

# Replace bootc's enabled apply-and-reboot schedule with a stage-only updater.
# The timer offers checks every two hours; the helper rate-limits successful
# checks to daily and retries deferred or failed checks at the next opportunity.
COPY --chmod=0755 files/usr/libexec/bootc-gnome-upgrade /usr/libexec/bootc-gnome-upgrade
COPY --chmod=0644 files/usr/lib/systemd/system/bootc-fetch-apply-updates.service.d/bootc-gnome.conf /usr/lib/systemd/system/bootc-fetch-apply-updates.service.d/bootc-gnome.conf
COPY --chmod=0644 files/usr/lib/systemd/system/bootc-fetch-apply-updates.timer.d/bootc-gnome.conf /usr/lib/systemd/system/bootc-fetch-apply-updates.timer.d/bootc-gnome.conf
RUN install -d -m 0755 /var/lib/bootc-gnome-upgrade \
    && systemctl enable bootc-fetch-apply-updates.timer

# Start the graphical desktop and network manager at boot.
RUN systemctl enable gdm.service NetworkManager.service

LABEL org.opencontainers.image.title="bootc-gnome"
LABEL org.opencontainers.image.description="A minimal Fedora bootc desktop with individually selected GNOME packages"
