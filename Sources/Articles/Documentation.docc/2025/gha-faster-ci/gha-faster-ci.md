# Faster CI in GitHub Actions

One of the biggest weakpoints of Swift is how slow the build system is.

## Speed Up Your CI Using actions/cache

```yaml
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Restore .build
        id: "restore-cache"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-build-${{ runner.os }}-"

      - name: Run unit tests
        if: ${{ steps.swift-check.outputs.swift-compatible == 'true' && (matrix.swift-config.build-mode == 'debug' || inputs.with_release_mode_testing) }}
        run: swift test --enable-code-coverage

      - name: Cache .build
        if: steps.restore-build.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .build
          key: "swiftpm-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
```

## Speed Up Cache Steps Using zstd

```yaml
      - name: Check out repository
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

```yaml
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

      # More Of Your CI Steps

      - name: Install Docker
        run: |
          # Make scripts executable
          chmod +x ./.github/scripts/*

          # Install Docker
          ./.github/scripts/install-docker.bash

      # More Of Your CI Steps

      - name: Build image
        run: docker build --network=host -t app:latest .
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
