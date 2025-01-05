# Faster CI in GitHub Actions

One of the biggest weak points of Swift is how slow the build system is.
You'll pay less for CI, or run out of less of your GitHub Actions free quota.

## The Problem

A usual CI file to test a Swift project can look like this.

```yaml
name: tests
on:
  pull_request: { types: [opened, reopened, synchronize, ready_for_review] }
  push: { branches: [main] }

jobs:
  unit-tests:
    runs-on: swift:6.0-noble
    steps:
      - name: Check out code
        uses: actions/checkout@v4

      - name: Run unit tests
        run: swift test --enable-code-coverage

      # Process the code coverage report, etc...
```

And with a CI file like so and a Dockerfile like [Vapor template's Dockerfile](https://github.com/vapor/template/blob/main/Dockerfile), you can deploy your apps to a cloud service that consumes Docker containers, such as AWS ECS, or DigitalOcean App Platform:

```yaml
name: deploy
on:
  push: { branches: [main] }

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build image
        run: docker build --network=host -t app:latest .

      # Push the image to a Docker container registry
```

## Use Swift and Ubuntu Jammy

In CI file:

```yaml
jobs:
  unit-tests:
    runs-on: swift:6.0-jammy
    steps:
      - name: Check out code
        uses: actions/checkout@v4

      - name: Run unit tests
        run: swift test --enable-code-coverage

      # Process the code coverage report, etc...
```

In Dockerfile:

`FROM swift:6.0-jammy`
`FROM ubuntu:jammy`

## Speed Up Your CI Using actions/cache

```yaml
      - name: Check out code
        uses: actions/checkout@v4

      - name: Restore .build
        id: "restore-cache"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-build-${{ runner.os }}-"

      - name: Run unit tests
        run: swift test --enable-code-coverage

      - name: Cache .build
        if: steps.restore-build.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
```

## Speed Up Cache Steps Using zstd

Although the CI times are looking much better now, you'll notice that the `Restore .build` and `Cache .build` steps themselves are taking at least a minute of time to finish. In bigger projects, they can easily ramp up to 4 or more minutes, just by themselves.

As it turns out, `actions/cache` compresses the directories before the upload. This compression process will use `gzip` by default, and considering that `gzip` does not run in parallel, it can easily take a minute for a 600 MiB `.build` directory to be compressed.

The hope is not lost though. The good news is that `actions/cache` will detect if it can use `zstd` instead of `gzip` for compression. If `zstd` is available, it'll use that instead.
For our purposes, `zstd` is much more performant than `gzip`, or even than `gzip`'s parallel implementation known as `pigz`, so we should use that instead.

Simple install `zstd` on the machine before any calls to `actions/cache`:

```yaml
      - name: Check out code
        uses: actions/checkout@v4

      - name: Install zstd
        run: |
          apt-get update -y
          apt-get install -y zstd

      - name: Restore .build
        id: "restore-cache"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-build-${{ runner.os }}-"

      - name: Run unit tests
        run: swift test --enable-code-coverage

      - name: Cache .build
        if: steps.restore-build.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
```

(Explain how much better things got)

## Separate Build Step From Test Runs

```yaml
      - name: Restore .build
        id: "restore-cache"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-build-${{ runner.os }}-"

      - name: Build package
        run: swift build

      - name: Cache .build
        if: steps.restore-build.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"

      - name: Run unit tests
        run: swift test --enable-code-coverage
```

## Optimize Build Steps For Maximum Speed

```yaml
      - name: Restore .build
        id: "restore-cache"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-build-${{ runner.os }}-"

      - name: Build package
        run: swift build --build-tests --enable-code-coverage

      - name: Cache .build
        if: steps.restore-build.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"

      - name: Run unit tests
        run: swift test --skip-build --enable-code-coverage
```

## Cache Build Artifacts When Using A Dockerfile

Need to change the `runs-on` to a Swift image, from an Ubuntu image.
Need to install Docker manually.
Need to modify the Dockerfile to only copy existing built stuff, and don't build the app itself.

```yaml
name: deploy
on:
  push: { branches: [main] }

jobs:
  deploy:
    runs-on: swift:6.0-jammy
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install zstd
        run: |
          apt-get update -y
          apt-get install -y zstd

      - name: Restore .build
        id: "restore-cache"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-build-${{ runner.os }}-"

      - name: Build App
        run: |
          apt-get update -y
          apt-get install -y libjemalloc-dev
          swift build \
            -c release \
            --static-swift-stdlib \
            -Xlinker -ljemalloc \
            $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

      - name: Cache .build
        if: steps.restore-build.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"

      - name: Install Docker
        run: |
          set -eu

          # https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository

          # Add Docker's official GPG key:
          apt-get update -y
          apt-get install ca-certificates curl gnupg -y
          install -m 0755 -d /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
          chmod a+r /etc/apt/keyrings/docker.gpg

          # Add the repository to Apt sources:
          # shellcheck source=/dev/null
          echo \
            "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              \"$(. /etc/os-release && echo "$VERSION_CODENAME")\" stable" |
            tee /etc/apt/sources.list.d/docker.list >/dev/null
          apt-get update -y

          # Install Docker:
          apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

      - name: Build image
        run: docker build --network=host -t app:latest .

      # Push the image to a Docker container registry
```

```diff
      - name: Build App
        run: |
          apt-get update -y
          apt-get install -y libjemalloc-dev
          swift build \
+            --product App \
            -c release \
            --static-swift-stdlib \
            -Xlinker -ljemalloc \
            $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)
```

```diff
-# Install OS updates
-RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
-    && apt-get -q update \
-    && apt-get -q dist-upgrade -y \
-    && apt-get install -y libjemalloc-dev
-
-# Set up a build area
-WORKDIR /build
-
-# First just resolve dependencies.
-# This creates a cached layer that can be reused
-# as long as your Package.swift/Package.resolved
-# files do not change.
-COPY ./Package.* ./
-RUN swift package resolve \
-        $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

+WORKDIR /staging

-# Build the application, with optimizations, with static linking, and using jemalloc
-# N.B.: The static version of jemalloc is incompatible with the static Swift runtime.
-RUN swift build -c release \
-        --product App \
-        --static-swift-stdlib \
-        -Xlinker -ljemalloc
-
-# Switch to the staging area
-WORKDIR /staging

# Copy main executable to staging area
-RUN cp "$(swift build --package-path /build -c release --show-bin-path)/App" ./
+RUN cp "$(swift build -c release --show-bin-path)/App" ./

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./
```

```dockerfile
# ================================
# Build image
# ================================
FROM swift:6.0-jammy AS build

WORKDIR /staging

# Copy entire repo into container
COPY . .

# Copy main executable to staging area
RUN cp "$(swift build -c release --show-bin-path)/App" ./

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy resources bundled by SPM to staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true
```

## When Things Go Wrong

Sometimes some inconsistency in the cached .build directory and what Swift expects, can result in build failures.
This usually manifests as weird build failures with no apparent reason and no helpful error logs, or when the error logs point to some code that no longer exists.

Thankfully this won't be frequent and theoretically shouldn't happen at all, and is also easy to work around.

When this happens, you can do any of the 3 following options:

1- Use `!(github.run_attempt > 1)` in an `if` condition so rerun of the same job doesn't use cache at all, and results in a clean build.

```diff
      - name: Restore .build
+        if: ${{ !(github.run_attempt > 1) }}
        id: "restore-cache"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-build-${{ runner.os }}-"
```

2- Use [this](https://github.com/actions/cache/blob/main/tips-and-workarounds.md#force-deletion-of-caches-overriding-default-cache-eviction-policy) simple workflow to delete all saved caches, so `Restore .build` step doesn't find anything to restore, and your build starts from a clean state.

3- Manually delete the caches through GitHub Actions UI:

![Delete Cache In GitHub UI](delete-caches-in-github-ui.png)
