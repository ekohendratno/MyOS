# LingmoOS source-first build

MixOS should not depend on the LingmoOS OBS CI packages for the core desktop
experience. Those packages can be useful as a fallback, but mixing them with
Debian testing packages produced a partial desktop: Settings pages stayed on
WLAN, dock launchers were inconsistent, and window behavior did not match a
coherent LingmoOS session.

The build is now source-first:

1. `scripts/build-lingmo-source.sh` clones `LingmoOS/LingmoOS`.
2. It bootstraps `lingmo-pkgbuild` from `LingmoOS/lingmo-pkgbuild` when the
   tool is not already installed.
3. It runs the upstream package flow:
   - `make config-pkgs`
   - `make build-pkgs`
4. Generated `.deb` files are cached in `artifacts/lingmo-source-debs`.
5. `build.sh` copies runtime packages into `config/packages.chroot` so
   live-build installs them into the ISO.

## Commands

Check the source toolchain without building the ISO:

```bash
sudo ./scripts/build-lingmo-source.sh --check-only
```

Build or refresh LingmoOS source packages:

```bash
sudo ./scripts/build-lingmo-source.sh
```

Build the ISO:

```bash
sudo ./build.sh --no-dry-run
```

Force a fresh LingmoOS source package rebuild:

```bash
sudo ./scripts/build-lingmo-source.sh --force
sudo ./build.sh --no-dry-run
```

## Important behavior

`LINGMO_SOURCE_REQUIRED="true"` means `build.sh` stops when source packages
cannot be built. This is intentional. It prevents a successful-looking ISO that
quietly falls back to the broken OBS-only desktop stack.

Temporary fallback for debugging only:

```bash
sudo ./build.sh --no-dry-run --skip-lingmo-source
```

## Upstream requirements

The LingmoOS source tree documents Debian 12, Debian 13, or later as supported
build hosts, with more than 50 GB of free disk, a multicore CPU, and at least
8 GB RAM. It also requires `lingmo-pkgbuild`, `make`, and a C/C++ compiler.
