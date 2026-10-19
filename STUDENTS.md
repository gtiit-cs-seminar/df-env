# Dataflow lab in Docker

If you can't get the dataflow lab working on your machine (JDK problems, downloads that never finish),
use the course's Docker image instead: it has a JDK 17, git, and everything the lab downloads (Gradle, Tai-e,
JUnit), so it works even without internet. It runs the same on Windows, macOS (Intel and Apple Silicon) and
Linux.

You still fork and clone your repo as the homework's README says; only building and running happen inside
the container.

## What to install (once)

1. **Docker**
   - Windows / macOS: [Docker Desktop](https://www.docker.com/products/docker-desktop/).
     On Windows, keep the **WSL 2** backend enabled (it's the default).
   - Linux: Docker Engine (`docker` from your package manager), and add your user to the `docker` group.
2. **VS Code** and the **Dev Containers** extension (`ms-vscode-remote.remote-containers`).

### If you were given the image as a file

Load it once, with Docker running:

- Mac with Apple Silicon (M1, M2, ...): `docker load -i df-env-arm64.tar.gz`
- Windows, Linux or Intel Mac: `docker load -i df-env-amd64.tar.gz`

(Not sure which Mac you have? Apple menu → *About This Mac*: if it says "Chip Apple M…", it's arm64.)

## Opening the project in VS Code

1. Clone your fork. **On Windows**, it's best to clone it *inside WSL* (in an Ubuntu terminal:
   `cd ~ && git clone ...`) and open it with `code .` from there; cloning under `C:\...` also works, but is
   much slower.
2. Tell VS Code to use the image: in your repo folder, create the file `.devcontainer/devcontainer.json`
   with this content (or download [this one](devcontainer-template/devcontainer.json) there):

   ```json
   { "name": "Dataflow lab", "image": "ghcr.io/gtiit-cs-seminar/df-env:latest" }
   ```

   You may commit it to your fork; it doesn't change anything for whoever doesn't use Docker.
3. Open the folder in VS Code. You'll get a **"Reopen in Container"** prompt (or `F1` → **Dev Containers:
   Reopen in Container**).
4. The first time, it downloads the image and VS Code installs its server and the Java extension inside the
   container (around 1 GB in total): it may sit on "Installing server" for several minutes. This happens
   only once; after that it opens in seconds. If Java support doesn't show up when it finishes, run `F1` →
   **Developer: Reload Window**.

The editor, the terminal and the Java extension then run inside the container. Your files stay in your
folder, so you commit and push as usual. In the VS Code terminal, run the commands of your homework's README:

```bash
./gradlew test
./gradlew zeroAnalysis -PtargetClass=seminar.dataflow.targets.ZeroAnalysis1
```

## Without VS Code

From your repo folder:

```bash
docker run --rm -it -v "$PWD":/workspace ghcr.io/gtiit-cs-seminar/df-env      # PowerShell: ${PWD}
# inside:
./gradlew test
```

On Linux, if your user ID isn't 1000, add `--user "$(id -u):$(id -g)"` so the files the build creates are
yours.

## Common problems

- **"Cannot connect to the Docker daemon"**: Docker Desktop isn't running.
- **`./gradlew: Permission denied`**: run `sh ./gradlew test`, or `chmod +x gradlew` once.
