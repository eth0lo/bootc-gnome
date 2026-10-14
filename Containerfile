FROM quay.io/fedora/fedora-bootc:latest

# Keep the desktop intentionally small: install only the GNOME components
# needed for a graphical session and basic desktop use. Do not install the
# Fedora Workstation package group.
RUN dnf -y --setopt=install_weak_deps=False install \
        gdm \
        gnome-control-center \
        gnome-session \
        gnome-settings-daemon \
        gnome-shell \
        gnome-terminal \
        gnome-text-editor \
        nautilus \
        NetworkManager-wifi \
        xdg-user-dirs \
    && dnf clean all

RUN systemctl enable gdm.service NetworkManager.service

LABEL org.opencontainers.image.title="bootc-gnome"
LABEL org.opencontainers.image.description="A minimal Fedora bootc desktop with individually selected GNOME packages"
