# syntax=docker/dockerfile:1

FROM ghcr.io/actions/actions-runner:2.338.2 AS actions-runner

FROM dhi.io/rust:1.100.0-debian13-dev

USER 0

# Minimal packages required by actions-runner (.NET runtime), Craft CI gate-setup
# (apt-get, sudo, git, curl, jq, archives), and native crate linking (build-essential, pkg-config).
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    jq \
    libicu76 \
    libkrb5-3 \
    libssl3 \
    passwd \
    pkg-config \
    sudo \
    unzip \
    xz-utils \
    zlib1g \
    zstd \
    && rm -rf /var/lib/apt/lists/*

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
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain none --no-modify-path \
    && chown -R 1001:1001 /usr/local/rustup /usr/local/cargo

# Copy GitHub Actions runner binaries and Node externals from the official ARC runner image.
COPY --from=actions-runner --chown=1001:1001 /home/runner /home/runner

ENV CARGO_HOME=/home/runner/.cargo \
    PATH=/cache/cargo/bin:/home/runner/.cargo/bin:/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    RUNNER_MANUALLY_TRAP_SIG=1 \
    ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

USER 1001
WORKDIR /home/runner

ENTRYPOINT ["/home/runner/run.sh"]
