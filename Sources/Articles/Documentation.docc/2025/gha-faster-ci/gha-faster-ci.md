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
This 4 minutes of CI runtime includes **100s** of tests runtime as well! If your tests take less time than that, your CI will be even faster.

## Separate Build Step From Test Runs

A logical problem in your current tests CI file is that if the tests fail, GitHub Actions will end the run and the "Cache .build" step won't be triggered.
This will be an annoyance in new pull requests, specially if they're big. Your CI will need to rebuild a large portion of the project, which might substantially increase the CI time, up to the original 10 minutes of CI time you had. But when the tests result in a failure, the cache step will be skipped, and in the next run it'll need to build the whole changes all over again.
You can fix this by separating the build step from the test-run step.
It's simple. Build the app first, run the tests later after you're done caching the changes:

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

Looks good, right?

Run the tests CI twice, to make sure the cache is updated. You'll notice a big regression. Even when cache is available, the CI runtime has gone back up to around 9 minutes 15 seconds.
Looking at runtimes of each step, you'll notice that the "Build package" step is only taking 1 minutes when a cache is available, but the "Run unit tests" is taking a whopping 7 minutes to run. It's as if the "Run unit tests" step is re-building majority of the project again.
How can we overcome this issue?

<!-- 9 minutes 15 seconds total.
1 minute build package, 7 minutes unit tests. -->

## Optimize Build Steps For Maximum Speed

There are a few tricks we haven't utilized yet.
Change your "Build package" and "Run unit tests" to the following:

```yaml
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

Rerun the job once again after the cache is updated. The CI runtime is down to **4 minutes 20 seconds**!
Great! You're almost back to the 4-minutes CI runtime mark, and only paying around 20 seconds of penalty to make sure the CI steps are more logical and account for unit tests failure in a better manner.

But how did this happen? It's simple! You were not caching all you could in the "Build package" step.
With the updated CI file, you're building the test targets as well thanks to the `--build-tests` flag, and also caching part of the code coverage work that the unit tests step would need to do, by using `--enable-code-coverage` in the build step. Note that you still need to use `--enable-code-coverage` in the unit-tests run step if you want to make sure code coverage is gathered in runtime of your unit tests as well.
Finally you use `--skip-build` flag when running unit tests, because you know you've already filly build the project and there is no reason to do it twice.

<!-- 4 minutes 20s total.
build package 1 minute, run unit tests 2 minutes. -->

## Cache Build Artifacts When Using A Dockerfile

Your tests CI is pretty fast now and only takes around 4 minutes.
But what about your deployments?
While there are a lot of similarities in implementing caching in tests CI and deployment CI, there are still some differences.
The project build in the deployment CI usually happens in a Dockerfile. While people have found ways around this, it's not easy to use `actions/cache` for files and folders that are in a Dockerfile.

To make your Dockerfile cache-friendly, you need to pull out the build step our of the Dockerfile and move it to the deployment CI GitHub Actions file.
For now, let's assume the build step is not happening in the Dockerfile, and the Dockerfile is only consuming the app that is already built.

Modify your Dockerfile like so. Note that the code-diff below is based on Vapor template's Dockerfile, which is also what Hummingbird template's Dockerfile is based on.
If you've changed your main executable's name from the default `App` to something else, make sure you substitute `App` with that name in the Dockerfile below:

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

This is how your Dockerfile will look like after the changes:

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

You're no longer building your app in the Dockerfile. You simply copy the whole repository to the Dockerfile like before, but you expect the repository to already contain the build artifacts and the built executable.

Let's not let down your Dockerfile! You need to modify the CI deployment file to not only properly build the project, but also to use caching like you've learned before.
You'll also need to add 2 extra things to the CI file. If you've changed your main executable's name from the default `App` to something else, make sure you substitute `App` with that name in the deployment file below as well:

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
+          # Installation commands from https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository:
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

Most of the new steps look familiar to you. You've already used them to speed up your tests CI.
On top of those caching steps, you also need to make sure to:
* Instruct GitHub Actions to run the CI file in a `swift:6.0-noble` container, instead of `ubuntu-latest`.
* Slightly modify the caching key to make sure your deployments don't go using your tests' caches!
  * You've simply modified `swiftpm-tests-build` to `swiftpm-deploy-build` in the cache keys above, and that's enough.
* Manually install Docker since swift images don't contain Docker.

The "Build App" step is mostly a copy of what was in the Dockerfile.
It installs jemalloac to be able to use it in the app compilation, and in the last line of the step, it makes sure to respect your current `Package.resolved` file instead of randomly updating your packages.

Rerun the deployment CI twice to make sure the cache is populated.
It's now taking a mere **3 minutes** for the deployment CI to finish, down from 14 minutes and a half!

## When Things Go Wrong

Sometimes some inconsistency in the cached .build directory and what Swift expects, can result in build failures.
This usually manifests as weird build failures with no apparent reason and no helpful error logs, or when the error logs point to something that should no longer exists.

Thankfully this won't be frequent and theoretically shouldn't happen at all. It's also easy to work around.

To avoid this issue, you have 3 options. Doing any one of them will suffice:

1- Using `!(github.run_attempt > 1)` in an `if` condition so reruns of the same job don't use cache at all, and result in a clean build.
This mean you'll be able to use the "Re-run jobs" button in the GitHub Actions UI, and have a clean build.

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

3- Manually delete the relevant caches through GitHub Actions UI:

![Delete Cache In GitHub UI](delete-caches-in-github-ui.png)

## RunsOn machines - runson/cache (If sponsored)

* Sometimes your project is too big and GitHub Actions runner runs out of memory, and you'll have to use bigger runners.
* Or maybe you simply want better CI times.
