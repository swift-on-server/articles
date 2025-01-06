# Faster CI in GitHub Actions

One of the biggest weak points of Swift is how slow the build system is. It can easily take anything between 10 to 40 minutes for a typical Swift CI to run depending on how big the project is, what build configuration you're using, and other factors.

By optimizing your CI runtime, you'll not only save precious developer time, but you'll also either pay less for CI, or consume less of your GitHub Actions free quota.

In this article, together we'll walk through optimizing [Vapor's Penny Bot](https://github.com/vapor/penny-bot) CI times to go from 10 minutes in tests and 14 minutes 30 seconds in deployments, down to less than 4 minutes for tests CI, and 3 minutes for deployments. The bigger your project is, the bigger the gap will be.

## The Problem

In [GitHub Actions](https://docs.github.com/actions), a usual CI file to run tests of a Swift project can look like this:

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
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run unit tests
        run: swift test --enable-code-coverage

      # Process the code coverage report, etc...
```

And with a CI file like so in combination with a Dockerfile like [Vapor](https://github.com/vapor/template/blob/main/Dockerfile) or [Hummingbird](https://github.com/hummingbird-project/template/blob/main/Dockerfile) template's Dockerfile, you can deploy your apps to a cloud service that consumes Docker images, such as AWS ECS, or DigitalOcean App Platform:

```yaml
name: deploy
on:
  push: { branches: [main] }

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build image
        run: docker build --network=host -t app:latest .

      # Push the image to a Docker container registry and deploy the app
```

As mentioned before, these CIs usually take 10 minutes in tests and 14 minutes 30 seconds for deployments in [Penny](https://github.com/vapor/penny-bot).
That's too much time wasted waiting. How can we improve these CI times?

## Speed Up Your CI Using actions/cache

Luckily for us, GitHub provides an [official cache action](https://github.com/actions/cache) that we can leverage in our CI.
For this, we need to make sure we cache SwiftPM's `.build` directory after our builds have succeeded, so the next build can restore that same cache for faster build times.
It'll look like this in the tests CI:

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

In the "Restore .build" step, we're using the `restore` capability of `actions/cache`, and asking it to restore our previously-uploaded cache to the `.build` directory.
The `key` is a way to uniquely identify caches. The `key` could look like `swiftpm-tests-build-Linux-f5ded47aafafe1f9f542e833a5f3dc01970bbaee`. If `actions/cache` finds and exact match for a cache with that name, it'll restore that cache for us. Otherwise it'll restore the latest cache that start with the `restore-keys`, which in our case will look like `swiftpm-tests-build-Linux-`. Note that `actions/cache` follows some branch protection rules so it's not vulnerable to cache poisoning attacks. That means that it'll only restore a cache if it was cached from the current branch or the primary branch of your repository.

In the "Cache .build" step, you're also simply caching your `.build` directory, now that the build and tests process is over. This is so the next CI runs can use this cache.
The `key` matches the one in the `key` of the "Restore .build" step, and with the `if` condition, we're trying to avoid spending time in the cache step when we've already found an exact cache key match in the "Restore .build" step. This is because `actions/cache` rejects cache entries with duplicate names, and does not have an update mechanism.

The `${{ github.event.pull_request.base.sha || github.event.after }}` in the cache `key` will also resolve to the base branch commit SHA of your pull request, or to the current commit SHA if the actions is triggered on a push event and not in a pull request.
This makes sure your pull request will use a cache from the commit the pull request is based on, and push events will usually fallback to the latest cache that has been uploaded from the branch the CI is running on.

Now let's see. How is your CI doing after adding these 2 steps?

For the first run, don't expect any time improvements as there is simply no cache the action run can use.
But if you re-run the CI job, you'll notice a big difference.
Your tests CI runtime will drop to 6 minutes 30s, saving 3 minutes 30s.
This is assuming both your restore and cache steps are run, which is not always true thanks to the if condition we have in "Cache .build" (`if: steps.restore-build.outputs.cache-hit != 'true'`). But in a lot of situations you'll still be restoring and uploading caches in the same CI run. For example every single time you push changes to a branch.

You've already saved at least 3 and a half minutes of time in your CI runtimes and that's great, but let's look closer.
What's consuming the CI runtime now that you're using caching? Is it really taking 6 and a half minutes for the tests to run even after your efforts?

The answer is No. Your Swift tests runtime has dropped to less than 3 minutes, but if you look at the "Cache .build" step in the first run of your CI, you'll notice "Cache .build" is taking more than **2 and a half minutes** caching around **1.5 GB** worth of `.build` data, with the "Restore .build" step taking around **30 seconds** in the next run to restore the data.

Wouldn't it be so nice if you could decrease the times spent caching? After all, only 3 minutes of your CI runtime is related to your test steps.

<!-- down to 6 minutes 30s. 30 seconds restore 2 minutes 50 seconds cache for 1.5 GB.
note not always cache step will be triggered. -->

## Speed Up Cache Steps Using zstd

As it turns out, `actions/cache` compresses the directories before uploading them to GitHub. This compression process will use `gzip` by default, and considering that `gzip` does not run in parallel, it can easily take 2 and a half minutes for a 1.5 GB `.build` directory to be compressed and uploaded.

The hope is not lost though. The good news is that `actions/cache` will detect if it can use `zstd` instead of `gzip` for compression, and if `zstd` is available, it'll use that instead.
For your purposes, `zstd` is much more performant than `gzip`, or even than `gzip`'s parallel implementation known as `pigz`, so you should leverage this feature.

Simply install `zstd` on the machine before any calls to `actions/cache`, so `actions/cache` can detect and use it:

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

Take another look at your CI times. The whole CI is running in **4 minutes**, down from 6 and a half minutes.
It's thanks to "Restore .build" only taking half the previous time at **15 seconds**, and "Cache .build" taking **less than 30s**, down from the previous 2 minutes and a half.
This 4 minutes of CI runtime includes **100s** of tests runtime as well! If your tests take less time than that, you're CI will be even faster.

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
      - name: Checkout code
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

3 minutes total.

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

* Sometimes your project is too big and GitHub Actions runner runs out of memory, and you'll have to use bigger runners.
* Or maybe you simply want better CI times.
