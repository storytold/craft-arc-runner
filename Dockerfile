# syntax=docker/dockerfile:1

FROM ghcr.io/actions/actions-runner:2.338.2 AS actions-runner

FROM dhi.io/rust:1.100.0-debian13-dev

USER 0

# Minimal packages required by actions-runner (.NET runtime), Craft CI gate-setup
# (apt-get, sudo, git, curl, jq, archives), the tools GitHub-hosted Ubuntu runners have that CI steps and the
# runner's own action download call (gzip, python3, which, hostname, ip, ssh, git-lfs, wget, rsync, zip, find, file,
# ps), and native crate linking (build-essential, pkg-config).
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    debianutils \
    file \
    findutils \
    git \
    git-lfs \
    gzip \
    hostname \
    iproute2 \
    jq \
    less \
    libicu76 \
    libkrb5-3 \
    libssl3 \
    openssh-client \
    passwd \
    pkg-config \
    procps \
    python3 \
    python-is-python3 \
    rsync \
    sudo \
    unzip \
    wget \
    which \
    xz-utils \
    zip \
    zlib1g \
    zstd \
    && rm -rf /var/lib/apt/lists/*

# The dev packages the Craft apps' CI gates install, preinstalled so the gate's apt step finds them.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libasound2-dev \
    libdbus-1-dev \
    libfontconfig1-dev \
    libfreetype-dev \
    libgl1-mesa-dev \
    libgtk-3-dev \
    libvulkan1 \
    libwayland-dev \
    libx11-dev \
    libxcb1-dev \
    libxcursor-dev \
    libxi-dev \
    libxkbcommon-dev \
    libxrandr-dev \
    mesa-vulkan-drivers \
    poppler-utils \
    qpdf \
    && rm -rf /var/lib/apt/lists/*

# The base image ships PAM without the common-* files that /etc/pam.d/sudo includes, so sudo aborts with
# "unable to initialize PAM"; pam-auth-update writes them from /usr/share/pam-configs.
RUN pam-auth-update --package --force

# Create runner user/group (uid/gid 1001) matching ARC expectations and grant passwordless sudo
# for gate-setup's install-apt-packages step.
RUN groupadd -g 1001 runner \
    && useradd -m -u 1001 -g 1001 -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner

# Install rustup (shims in /usr/local/cargo/bin, toolchains in /usr/local/rustup)
# so gate-setup can run `rustup toolchain install` while CARGO_HOME=/cache/cargo on runner pods.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
# The gate installs `stable` (with clippy, rustfmt and the wasm target) when a repo pins no channel; having it in the
# image turns that step into an update check instead of a ~300 MB download per job. The PR runner set mounts /cache
# read-only, so the toolchain lives in the image rather than on the node cache.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain none --no-modify-path \
    && /usr/local/cargo/bin/rustup toolchain install stable --profile minimal \
       --component clippy --component rustfmt --target wasm32-unknown-unknown \
    && /usr/local/cargo/bin/rustup default stable \
    && chown -R 1001:1001 /usr/local/rustup /usr/local/cargo

# Copy GitHub Actions runner binaries and Node externals from the official ARC runner image.
COPY --from=actions-runner --chown=1001:1001 /home/runner /home/runner
# Steps that install tools unpack them into ~/.cargo/bin, which hosted runners have and PATH already lists.
RUN install -d -o 1001 -g 1001 /home/runner/.cargo /home/runner/.cargo/bin

# The docker CLI and buildx plugin from the same image: the runner sets use dind mode, so container actions, service
# containers and `docker build` steps call the CLI against the dind sidecar.
COPY --from=actions-runner /usr/bin/docker /usr/bin/docker
COPY --from=actions-runner /usr/local/lib/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx

ENV CARGO_HOME=/home/runner/.cargo \
    PATH=/cache/cargo/bin:/home/runner/.cargo/bin:/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    RUNNER_MANUALLY_TRAP_SIG=1 \
    ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

USER 1001
WORKDIR /home/runner

ENTRYPOINT ["/home/runner/run.sh"]
