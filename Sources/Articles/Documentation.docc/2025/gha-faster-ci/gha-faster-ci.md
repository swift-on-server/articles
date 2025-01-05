# Faster CI in GitHub Actions

One of the biggest weak points of Swift is how slow the build system is. It can easily take anything between 10 to 40 minutes for a typical Swift CI to run, depending on how big the project is, what build configuration you're using, and other factors.
By optimizing your CI runtime, you'll not only save precious developer time, but you'll also either pay less for CI, or consume less of your GitHub Actions free quota.
In this article, we'll walk through optimizing [Vapor's Penny Bot](https://github.com/vapor/penny-bot) CI times to go from 10 minutes in tests and 14 minutes 30 seconds in deployments, down to less than 4 and 8 minutes. The bigger your project is, the bigger the gap will be.

## The Problem

A usual CI file to test a Swift project can look like this:

```yaml
name: tests
on:
  pull_request: { types: [opened, reopened, synchronize, ready_for_review] }
  push: { branches: [main] }

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    container: swift:6.0-noble
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

As mentioned before, these CIs usually take 10 minutes in tests and 14 minutes 30 seconds for deployments in [Penny](https://github.com/vapor/penny-bot).
How can we improve them?

## Speed Up Your CI Using actions/cache

```diff
+      - name: Restore .build
+        id: "restore-build"
+        uses: actions/cache/restore@v4
+        with:
+          path: .build
+          key: "swiftpm-tests-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
+          restore-keys: "swiftpm-tests-build-${{ runner.os }}-"

      - name: Run unit tests
        run: swift test --enable-code-coverage

+      - name: Cache .build
+        if: steps.restore-build.outputs.cache-hit != 'true'
+        uses: actions/cache/save@v4
+        with:
+          path: .build
+          key: "swiftpm-tests-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
```

down to 6 minutes 30s. 30 seconds restore 2 minutes 50 seconds cache for 1.5 GB.
note not always cache step will be triggered.

## Speed Up Cache Steps Using zstd

Although the CI times are looking much better now, you'll notice that the `Restore .build` and `Cache .build` steps themselves are taking at least a minute of time to finish. In bigger projects, they can easily ramp up to 4 or more minutes, just by themselves.

As it turns out, `actions/cache` compresses the directories before the upload. This compression process will use `gzip` by default, and considering that `gzip` does not run in parallel, it can easily take a minute for a 600 MiB `.build` directory to be compressed.

The hope is not lost though. The good news is that `actions/cache` will detect if it can use `zstd` instead of `gzip` for compression. If `zstd` is available, it'll use that instead.
For our purposes, `zstd` is much more performant than `gzip`, or even than `gzip`'s parallel implementation known as `pigz`, so we should use that instead.

Simply install `zstd` on the machine before any calls to `actions/cache`:

```diff
+      - name: Install zstd
+        run: |
+          apt-get update -y
+          apt-get install -y zstd

      - name: Restore .build
        id: "restore-build"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-tests-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-tests-build-${{ runner.os }}-"

      - name: Run unit tests
        run: swift test --enable-code-coverage
```

down to 4 minutes. 15 seconds restore 30 seconds cache. 1.4 GB of cache.
100 seconds tests.

## Separate Build Step From Test Runs

Times are assuming to purge the previous caches (explained in a step below)

```diff
      - name: Restore .build
        id: "restore-build"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-tests-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-tests-build-${{ runner.os }}-"

-      - name: Run unit tests
-        run: swift test --enable-code-coverage
+      - name: Build package
+        run: swift build

      - name: Cache .build
        if: steps.restore-build.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .build
          key: "swiftpm-tests-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"

+      - name: Run unit tests
+        run: swift test --enable-code-coverage
```

9 minutes 15 seconds total.
1 minute build package, 7 minutes unit tests.

## Optimize Build Steps For Maximum Speed

```yaml
      - name: Restore .build
        id: "restore-build"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-tests-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-tests-build-${{ runner.os }}-"

      - name: Build package
-        run: swift build
+        run: swift build --build-tests --enable-code-coverage

      - name: Cache .build
        if: steps.restore-build.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .build
          key: "swiftpm-tests-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"

      - name: Run unit tests
-        run: swift test --enable-code-coverage
+        run: swift test --skip-build --enable-code-coverage
```

4 minutes 20s total.
build package 1 minute, run unit tests 2 minutes.

## Cache Build Artifacts When Using A Dockerfile

Need to change the `runs-on` to a Swift image, from an Ubuntu image.
Need to install Docker manually.
Need to modify the Dockerfile to only copy existing built stuff, and don't build the app itself.
Use different caching key.
Use `--product App`.

```diff
name: deploy
on:
  push: { branches: [main] }

jobs:
  deploy:
    runs-on: ubuntu-latest
+    container: swift:6.0-noble
    steps:
      - name: Checkout
        uses: actions/checkout@v4

+      - name: Install zstd
+        run: |
+          apt-get update -y
+          apt-get install -y zstd
+
+      - name: Restore .build
+        id: "restore-build"
+        uses: actions/cache/restore@v4
+        with:
+          path: .build
+          key: "swiftpm-deploy-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
+          restore-keys: "swiftpm-deploy-build-${{ runner.os }}-"
+
+      - name: Build App
+        run: |
+          apt-get update -y
+          apt-get install -y libjemalloc-dev
+          swift build \
+            -c release \
+            --product App \
+            --static-swift-stdlib \
+            -Xlinker -ljemalloc \
+            $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)
+
+      - name: Cache .build
+        if: steps.restore-build.outputs.cache-hit != 'true'
+        uses: actions/cache/save@v4
+        with:
+          path: .build
+          key: "swiftpm-deploy-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
+
+      - name: Install Docker
+        run: |
+          set -eu
+
+          # https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
+
+          # Add Docker's official GPG key:
+          apt-get update -y
+          apt-get install ca-certificates curl gnupg -y
+          install -m 0755 -d /etc/apt/keyrings
+          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
+          chmod a+r /etc/apt/keyrings/docker.gpg
+
+          # Add the repository to Apt sources:
+          # shellcheck source=/dev/null
+          echo \
+            "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
+              \"$(. /etc/os-release && echo "$VERSION_CODENAME")\" stable" |
+            tee /etc/apt/sources.list.d/docker.list >/dev/null
+          apt-get update -y
+
+          # Install Docker:
+          apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

      - name: Build image
        run: docker build --network=host -t app:latest .
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

# Copy resources bundled by SPM to staging area
-RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;
+RUN find -L "$(swift build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
-RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
-RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true
+RUN [ -d ./Public ] && { chmod -R a-w ./Public; } || true
+RUN [ -d ./Resources ] && { chmod -R a-w ./Resources; } || true
```

This will be what you have after the changes:

```dockerfile
# ================================
# Build image
# ================================
FROM swift:6.0-noble AS build

WORKDIR /staging

# Copy entire repo into container
COPY . .

# Copy main executable to staging area
RUN cp "$(swift build -c release --show-bin-path)/App" ./

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy resources bundled by SPM to staging area
RUN find -L "$(swift build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d ./Public ] && { chmod -R a-w ./Public; } || true
RUN [ -d ./Resources ] && { chmod -R a-w ./Resources; } || true
```

3 minutes 30 seconds total.


mention that all times include 25s of caching .build. That won't happen at all if "Restore .build" has found an exact match for the cache key, for example in PRs.

## When Things Go Wrong

Sometimes some inconsistency in the cached .build directory and what Swift expects, can result in build failures.
This usually manifests as weird build failures with no apparent reason and no helpful error logs, or when the error logs point to some code that no longer exists.

Thankfully this won't be frequent and theoretically shouldn't happen at all, and is also easy to work around.

When this happens, you can do any of the 3 following options:

1- Use `!(github.run_attempt > 1)` in an `if` condition so rerun of the same job doesn't use cache at all, and results in a clean build.

```diff
      - name: Restore .build
+        if: ${{ !(github.run_attempt > 1) }}
        id: "restore-build"
        uses: actions/cache/restore@v4
        with:
          path: .build
          key: "swiftpm-tests-build-${{ runner.os }}-${{ github.event.pull_request.base.sha || github.event.after }}"
          restore-keys: "swiftpm-tests-build-${{ runner.os }}-"
```

2- Use [this](https://github.com/actions/cache/blob/main/tips-and-workarounds.md#force-deletion-of-caches-overriding-default-cache-eviction-policy) simple workflow to delete all saved caches, so `Restore .build` step doesn't find anything to restore, and your build starts from a clean state.

3- Manually delete the caches through GitHub Actions UI:

![Delete Cache In GitHub UI](delete-caches-in-github-ui.png)

## RunsOn machines - runson/cache (If sponsored)
