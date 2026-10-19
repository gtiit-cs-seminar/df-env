# Opens VS Code inside the df-env container, with a folder mounted at
# /workspace (Windows version of open-vscode.sh). Requires Docker Desktop,
# VS Code with the "Dev Containers" extension, and the `code` command on the PATH.
#
# Usage (PowerShell):
#   powershell -ExecutionPolicy Bypass -File open-vscode.ps1 [folder]
#   powershell -ExecutionPolicy Bypass -File open-vscode.ps1 -Stop [folder]
param(
    [switch]$Stop,
    [string]$Folder = "."
)
$ErrorActionPreference = "Stop"

$Image = if ($env:IMAGE) { $env:IMAGE } else { "ghcr.io/gtiit-cs-seminar/df-env:latest" }

$Dir = (Resolve-Path $Folder).Path
$Base = (Split-Path $Dir -Leaf) -replace '[^A-Za-z0-9_.-]', '-'
$Sha1 = [System.Security.Cryptography.SHA1]::Create()
$Hash = ([System.BitConverter]::ToString($Sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Dir))) -replace '-', '').Substring(0, 6).ToLower()
$Name = "df-env-$Base-$Hash"

if ($Stop) {
    docker rm -f $Name
    exit
}

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Error "Can't find the 'code' command. Reinstall VS Code with 'Add to PATH' checked."
}

$State = docker inspect -f '{{.State.Running}}' $Name 2>$null
if ($LASTEXITCODE -ne 0) { $State = "none" }

switch ($State) {
    "true"  { Write-Host ">> Using container $Name" }
    "false" { Write-Host ">> Starting container $Name"; docker start $Name | Out-Null }
    default {
        Write-Host ">> Creating container $Name with $Dir at /workspace"
        # df-env-vscode-server: VS Code's server and extensions
        # (~700 MB) are downloaded once and shared across containers.
        docker run -d --init --name $Name -v "${Dir}:/workspace" -w /workspace `
            -v df-env-vscode-server:/home/student/.vscode-server $Image sleep infinity | Out-Null
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }
}

# VS Code identifies the container by a hex-encoded JSON.
$Json = '{"containerName":"/' + $Name + '"}'
$Hex = ([System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($Json)) -replace '-', '').ToLower()
code --folder-uri "vscode-remote://attached-container+$Hex/workspace"

Write-Host ">> Done. To remove the container: open-vscode.ps1 -Stop `"$Dir`""
