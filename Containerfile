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

# In bootc, /home points to /var/home. Create that parent directory at boot;
# PAM/oddjob creates each user's /var/home/<user> directory on first login.
COPY --chmod=0644 files/usr/lib/tmpfiles.d/bootc-gnome-home.conf /usr/lib/tmpfiles.d/bootc-gnome-home.conf
COPY --chmod=0644 files/etc/polkit-1/rules.d/10-rpmostree-repo-refresh.rules /etc/polkit-1/rules.d/10-rpmostree-repo-refresh.rules

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
