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

## Optimize The Build Step For Maximum Speed

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
        run: swift build --product App

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

```dockerfile
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev

WORKDIR /staging

# Copy main executable to staging area
COPY .build/debug/App ./

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./
```

## Cache Can Go Broken Once In A While

Use `!(github.run_attempt > 1)` in an `if` condition so rerun of the same job doesn't use cache at all, which results in a clean build.

```yaml
      - name: Restore .build
        if: ${{ !(github.run_attempt > 1) }}
        id: "restore-cache"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-build-${{ runner.os }}-"
```
