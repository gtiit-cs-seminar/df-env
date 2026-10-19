# Environment for the dataflow lab (HW1, HW1 plus and HW1 bonus, on Tai-e), for
# students whose own setup doesn't work or whose downloads are slow: JDK 17, git,
# and everything the student repos download (Gradle 9.8.1, Tai-e, JUnit), so
# `./gradlew test` works without network.
#
# The cache is filled by building the three public skeletons from GitHub, so it
# matches what the real repos use. Rebuild the image when their build.gradle or
# Gradle version changes.
#
# Multi-architecture (linux/amd64 and linux/arm64), so it runs natively on
# Windows/Linux x86 and on Apple Silicon Macs.
#
#   docker buildx build --platform linux/amd64,linux/arm64 -t <image> --push .
#
# See README.md (instructor) and STUDENTS.md (students).

FROM eclipse-temurin:17-jdk-noble

ARG USERNAME=student
ARG USER_UID=1000
ARG USER_GID=1000

ENV LANG=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        git unzip less nano vim-tiny sudo bash-completion ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# The Ubuntu Noble base image ships a "ubuntu" user with UID 1000; replace it
# with "student" (on Linux, VS Code remaps the UID to the host user's).
RUN (userdel -r ubuntu 2>/dev/null || true) \
 && groupadd --gid "$USER_GID" "$USERNAME" \
 && useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /bin/bash "$USERNAME" \
 && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
 && chmod 0440 "/etc/sudoers.d/$USERNAME"

# Gradle's user home (the Gradle distribution the wrapper downloads, and the
# dependency cache) lives outside $HOME and is world-writable, so it works for
# any UID (`docker run --user`, VS Code's UID remapping on Linux).
ENV GRADLE_USER_HOME=/opt/gradle-home

# Slow or flaky networks: long HTTP timeouts and retries for the dependency
# downloads (kept in the image, they help students online too), and a retry
# helper for the build steps below.
RUN mkdir -p "$GRADLE_USER_HOME" \
 && printf '%s\n' \
        'org.gradle.internal.http.connectionTimeout=120000' \
        'org.gradle.internal.http.socketTimeout=120000' \
        'org.gradle.internal.repository.max.retries=5' \
        > "$GRADLE_USER_HOME/gradle.properties"
COPY --chmod=0755 retry /usr/local/bin/retry

ARG REPOS="df-zero-analysis df-zero-analysis-plus df-interval-analysis"
ARG ORG_URL=https://github.com/gtiit-cs-seminar

# The Gradle distribution (~140 MB), in its own layer so a later failure doesn't
# download it again. The wrapper caches it under a hash of distributionUrl, so it
# must come from the repos' own URL; only the read timeout is raised here.
RUN set -eux; \
    repo="${REPOS%% *}"; \
    git clone -q --depth 1 "$ORG_URL/$repo.git" /tmp/dist-warmup; \
    cd /tmp/dist-warmup; \
    sed -i 's/^networkTimeout=.*/networkTimeout=120000/' gradle/wrapper/gradle-wrapper.properties; \
    retry ./gradlew --no-daemon -q --version; \
    rm -rf /tmp/dist-warmup "$GRADLE_USER_HOME/daemon" "$GRADLE_USER_HOME/.tmp"

# The dependencies: run, in each skeleton, every task a student runs: the tests
# and the analysis task (both fail in a skeleton, whose exercises throw
# UnsupportedOperationException: that is expected, the point is the downloads).
# Then check it all builds offline. Made world-writable in the same layer: a
# later `chmod -R` would copy all of it into a new layer.
RUN set -eux; \
    for repo in $REPOS; do \
        git clone -q --depth 1 "$ORG_URL/$repo.git" "/tmp/warmup/$repo"; \
        cd "/tmp/warmup/$repo"; \
        retry ./gradlew --no-daemon -q compileJava compileTestJava; \
        ./gradlew --no-daemon -q test > /dev/null 2>&1 || true; \
        test -d build/test-results/test; \
        if [ -f src/main/java/seminar/dataflow/Launcher.java ]; then \
            ./gradlew --no-daemon -q zeroAnalysis -PtargetClass=seminar.dataflow.targets.ZeroAnalysis1 > /dev/null 2>&1 || true; \
        else \
            ./gradlew --no-daemon -q intervalAnalysis -PtargetClass=seminar.dataflow.intervaltargets.IntervalAnalysis1 > /dev/null 2>&1 || true; \
        fi; \
        ./gradlew --no-daemon -q --offline clean compileTestJava; \
    done; \
    rm -rf /tmp/warmup "$GRADLE_USER_HOME/daemon" "$GRADLE_USER_HOME/.tmp"; \
    chmod -R a+rwX "$GRADLE_USER_HOME"

# ~/.vscode-server must exist and be owned by the user so that the
# df-env-vscode-server volume (see the label below) is initialized with that owner.
RUN mkdir -p /workspace "/home/$USERNAME/.vscode-server" \
 && chown "$USERNAME:$USERNAME" /workspace "/home/$USERNAME/.vscode-server"

# VS Code (Dev Containers) configuration, applied both when a repo is opened
# through its .devcontainer/devcontainer.json and with "Attach to Running
# Container" (see open-vscode.sh). The df-env-vscode-server volume keeps VS
# Code's server and extensions across containers, so they download only once.
LABEL devcontainer.metadata='[{ \
  "remoteUser": "student", \
  "mounts": [{ "source": "df-env-vscode-server", "target": "/home/student/.vscode-server", "type": "volume" }], \
  "customizations": { "vscode": { \
    "extensions": ["vscjava.vscode-java-pack"], \
    "settings": { \
      "java.configuration.runtimes": [{ "name": "JavaSE-17", "path": "/opt/java/openjdk", "default": true }], \
      "java.import.gradle.java.home": "/opt/java/openjdk", \
      "java.import.gradle.user.home": "/opt/gradle-home", \
      "java.configuration.updateBuildConfiguration": "automatic", \
      "java.compile.nullAnalysis.mode": "disabled" \
    } \
  } } \
}]'

USER ${USERNAME}
WORKDIR /workspace
CMD ["bash"]
