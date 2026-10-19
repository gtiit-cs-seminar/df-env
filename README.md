# df-env

Docker image for the **dataflow lab** (HW1, HW1 plus and HW1 bonus, on Tai-e): **JDK 17 (Temurin) + git**, with
everything the student repos download pre-cached: the Gradle 9.8.1 distribution of the wrapper, Tai-e 0.5.4
and its dependencies, JUnit 5. `./gradlew test` works offline. Multi-architecture: `linux/amd64` and
`linux/arm64`, so it runs natively on Windows, Linux and Apple Silicon Macs.

The lab doesn't need it: a JDK 17+ on the student's machine is enough. The image is the fallback for
students whose setup fails or whose downloads are too slow. Student instructions: [STUDENTS.md](STUDENTS.md).

## What's in the image

| What | Details |
| --- | --- |
| `java`, `javac` | Temurin 17, `JAVA_HOME=/opt/java/openjdk` |
| `/opt/gradle-home` | `GRADLE_USER_HOME`: the Gradle distribution and the dependency cache; writable by any user |
| `git`, `nano`, `vi`, `less`, `unzip` | |
| user `student` (UID 1000) | Default user; passwordless sudo; `WORKDIR /workspace` |
| label `devcontainer.metadata` | VS Code config: Java extension, JDK 17, Gradle user home, `df-env-vscode-server` volume |

The cache is filled at build time by cloning the three public skeletons
(`gtiit-cs-seminar/df-zero-analysis`, `-plus`, `df-interval-analysis`) and running their tests and analysis
task; the build then checks they compile with `--offline`. **Rebuild the image when their `build.gradle` or
the Gradle version changes**; otherwise the new things are downloaded on first use (and fail offline).

## Build and publish

With [`.github/workflows/publish-image.yml`](.github/workflows/publish-image.yml) (this folder is the
`gtiit-cs-seminar/df-env` repo), the image is published to `ghcr.io/gtiit-cs-seminar/df-env:latest` (and
`:<sha>`) on every push to `main`. **After the first publish, make the package public on GHCR** (Packages →
df-env → Package settings → Change visibility) so students can pull it without logging in.

By hand:

```bash
# local, only your machine's architecture
docker build -t ghcr.io/gtiit-cs-seminar/df-env:latest .

# multi-arch and push (requires `docker login ghcr.io`)
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/gtiit-cs-seminar/df-env:latest --push .
```

### As tar files (no registry)

```bash
./export-tars.sh            # produces dist/df-env-{amd64,arm64}.tar.gz + SHA256SUMS
```

One tar per architecture: `amd64` for Windows, Linux and Intel Macs; `arm64` for Apple Silicon Macs. Load
with `docker load -i <file>`; the image gets the name the devcontainer uses, so VS Code doesn't try to pull
it. On an Apple Silicon Mac the `amd64` build is emulated (QEMU) and takes several minutes.

## Devcontainer

The student repos don't include a devcontainer: the lab runs with just a JDK, and the image is only a
fallback. [STUDENTS.md](STUDENTS.md) tells a student who needs it to add
[`devcontainer-template/devcontainer.json`](devcontainer-template/devcontainer.json) as
`.devcontainer/devcontainer.json` in their fork. It only names the image; the user, extension, settings and
volume come from the image's `devcontainer.metadata` label. For a submission, `open-vscode.sh` (below) needs
no devcontainer at all.

## Open any folder in VS Code, inside the container

```bash
./open-vscode.sh ~/submissions/group3          # Windows: powershell -ExecutionPolicy Bypass -File open-vscode.ps1 C:\submissions\group3
./open-vscode.sh --stop ~/submissions/group3   # removes the container (the files stay in the folder)
```

Starts a container (`df-env-<folder>-<hash>`) with the folder at `/workspace` and opens VS Code attached to
it; the folder doesn't need a `devcontainer.json`. The first time, VS Code downloads its server and the
extension (it depends on each person's VS Code version, so it can't be baked into the image); they're kept
in the `df-env-vscode-server` volume, shared by every container.

## Running a repo from the command line

```bash
docker run --rm -it -v "$PWD":/workspace ghcr.io/gtiit-cs-seminar/df-env ./gradlew test
```

Add `--network none` to check it works offline. On Linux, if your UID isn't 1000, add
`--user "$(id -u):$(id -g)"` (any UID works: the Gradle home is world-writable).
