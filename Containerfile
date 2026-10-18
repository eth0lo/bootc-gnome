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

# Start the graphical desktop and network manager at boot.
RUN systemctl enable gdm.service NetworkManager.service

LABEL org.opencontainers.image.title="bootc-gnome"
LABEL org.opencontainers.image.description="A minimal Fedora bootc desktop with individually selected GNOME packages"
