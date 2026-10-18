# Retain PackageKit client library for Document Scanner

The image omits GNOME Software and the PackageKit daemon so bootc remains the supported OS-update path, but retains `PackageKit-glib` because GNOME Document Scanner (`simple-scan`) has a hard dependency on the client library. Keeping this library preserves desktop scanning support without retaining PackageKit's OS-update service; printer support is retained while DNF excludes the daemon as a weak dependency.
