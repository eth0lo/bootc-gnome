FROM quay.io/fedora/fedora-bootc:43

# Use the Fedora 43 GNOME group selection documented in FEDORA-43-GROUPS.md,
# not the broader Workstation environment. Keep first-boot account creation
# available through GNOME Initial Setup.
RUN dnf -y group install \
        core \
        base-graphical \
        gnome-desktop \
        domain-client \
        hardware-support \
        printing \
        multimedia \
    && dnf -y install \
        authselect \
        gdm \
        glibc-langpack-en \
        NetworkManager-wifi \
    && dnf clean all

RUN install -d -m 0755 /var/home \
    && printf 'd /var/home 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-gnome-home.conf \
    && install -d -m 0755 /etc/polkit-1/rules.d \
    && printf '%s\n' \
        'polkit.addRule(function(action, subject) {' \
        '    if (action.id === "org.projectatomic.rpmostree1.repo-refresh" &&' \
        '        subject.active === true &&' \
        '        subject.local === true &&' \
        '        (subject.isInGroup("wheel") || subject.isInGroup("sudo"))) {' \
        '        return polkit.Result.YES;' \
        '    }' \
        '});' > /etc/polkit-1/rules.d/10-rpmostree-repo-refresh.rules \
    && authselect enable-feature with-mkhomedir \
    && systemctl enable gdm.service NetworkManager.service oddjobd.service

LABEL org.opencontainers.image.title="bootc-gnome"
LABEL org.opencontainers.image.description="A minimal Fedora bootc desktop with individually selected GNOME packages"
