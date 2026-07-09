# Installing Docker on Windows with WSL2

A quick guide covering the steps used to get Docker running inside WSL on Windows.

## 1. Install WSL2

Open PowerShell **as Administrator** and run:

```powershell
wsl --install
```

This installs WSL2 along with a default Linux distro (Ubuntu). Restart your computer if prompted.

If WSL was already installed, make sure it's set to version 2:

```powershell
wsl --set-default-version 2
```

## 2. Install Docker Desktop for Windows

- Download it from the official site: https://www.docker.com/products/docker-desktop/
- Choose the **Windows** version:
  - **AMD64** — for standard Intel/AMD PCs (most common)
  - **ARM64** — only for ARM-based Windows devices (e.g. Surface Pro X)
  - Check your architecture in PowerShell if unsure:
    ```powershell
    echo $env:PROCESSOR_ARCHITECTURE
    ```
- Run the installer and make sure **"Use WSL 2 instead of Hyper-V"** is checked during setup.

## 3. Enable WSL Integration

- Open Docker Desktop → **Settings** → **Resources** → **WSL Integration**
- Enable integration for your distro (e.g. Ubuntu)
- Click **Apply & Restart**

## 4. Verify the Installation

Open your WSL terminal and check the Docker version:

```bash
docker --version
```

Then test it by pulling and running a container. For example:

```bash
docker run --detach --publish-all nginx:1.20
```

Check that it's running with:

```bash
docker ps
```

Expected output looks like:

```
CONTAINER ID   IMAGE        COMMAND                  CREATED          STATUS          PORTS                     NAMES
ea0691e97ae3   nginx:1.20   "/docker-entrypoint.…"   33 seconds ago   Up 31 seconds   0.0.0.0:32768->80/tcp    kind_dijkstra
```

✅ If you see your container listed with an `Up` status, Docker is successfully installed and working inside WSL.

---

**Notes:**
- `--publish-all` maps the container's exposed ports to random available ports on the host — check the `PORTS` column in `docker ps` to find which port to use (in this case, port `32768`).
- You can stop the container with `docker stop <CONTAINER ID>` and remove it with `docker rm <CONTAINER ID>`.