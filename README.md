# hclaude: Claude Code in a podman + krun microVM

Runs Claude Code in a microVM that sees only the project directory and its own config volume. It installs as `claude`, for hosts where Claude Code is only ever run sandboxed.

## Install (Fedora)
    sudo dnf install git podman crun-krun     # libkrun >= 1.8
    curl -fsSL https://raw.githubusercontent.com/monday-j/hclaude/main/install.sh | bash

The installer checks the dependencies (it never runs sudo; it prints the `dnf` command if anything is missing), clones this repo into `~/.local/share/hclaude`, links `~/.local/bin/claude` to it, and runs a krun smoke test. It refuses to overwrite an existing `~/.local/bin/claude` that isn't this wrapper. Rerunning it updates the checkout. `HCLAUDE_REPO`, `HCLAUDE_DIR` and `HCLAUDE_BIN` override the source, checkout and link.

For development, link a working copy instead: `ln -s "$PWD/hclaude" ~/.local/bin/claude` (any name works).

## Use
    cd ~/some/project
    claude              # builds the image on first use, log in once
    claude -c           # any claude arguments pass straight through (--resume, -p "...", ...)
    claude shell        # bash inside the VM
    claude update       # pull the latest wrapper and rebuild the image (latest Claude Code)
    claude uninstall    # remove the wrapper; asks before deleting images and the config volume

The wrapper's own commands (`init`, `build`, `run`, `shell`, `netcheck`, `import-claude-md`, `update`, `uninstall`, `help`) shadow any Claude Code subcommand of the same name. That is intended for `update`, since the VM's Claude Code can only be updated by rebuilding the image.

Credentials persist in the volume `hclaude-config`. The project is mounted at its real host path, so Claude's per-project history and trust settings stay separate. The VM uses the host's timezone.

The Claude Code version is fixed when the image is built. An interactive run rebuilds the image first if it is more than `HCLAUDE_UPDATE_DAYS` (default 7) old, which refreshes Claude Code and the Fedora packages. Scripted runs (`-p`, pipes) are never delayed, a failed update (e.g. offline) keeps the old image, and `HCLAUDE_NO_UPDATE=1` skips the check. This is age-based, not a check for a newer release. `claude update` (or `claude build`, which skips pulling the wrapper) forces a refresh at any time. Old image layers are left behind, so run `podman image prune` now and then.

`claude init` is only needed for a per-project toolchain: it creates `.hclaude/Containerfile`, which is built automatically on the next run (rerun `claude build` after editing it). `HCLAUDE_RAM_MIB` and `HCLAUDE_CPUS` set VM size.

`claude import-claude-md` copies your global `~/.claude/CLAUDE.md` into the sandbox. It is not done by default.

## What the VM can and can't see
- Mounted: the project at its host path and the `hclaude-config` volume.
- Not mounted or passed: `~/.ssh`, `SSH_AUTH_SOCK`, `~/.kube`, cloud credentials.
- Not a perfect boundary (see the libkrun security model). Outbound internet is open.
