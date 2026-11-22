# craft-arc-runner

Minimal GitHub Actions Runner Controller (ARC) container image for Craft CI Linux jobs, built on `dhi.io/rust:1-debian13-dev`.

Includes only:
- `actions/runner` (`/home/runner`) from `ghcr.io/actions/actions-runner:latest`
- `rustup` (`/usr/local/rustup`, shims in `/usr/local/cargo/bin`) with the `stable` toolchain (clippy, rustfmt, `wasm32-unknown-unknown`) preinstalled
- the `docker` CLI and buildx plugin from `ghcr.io/actions/actions-runner`, for the dind runner sets
- `build-essential` and `pkg-config` for native Rust crate linking
- `git`, `curl`, `ca-certificates`, `jq`, `sudo`, `unzip`, `xz-utils`, `zstd`, and `.NET` runtime libs required by `actions/runner`
- Non-root `runner` user (`uid 1001`) with passwordless `sudo` for `install-apt-packages`

Image: `ghcr.io/storytold/craft-arc-runner:latest`
