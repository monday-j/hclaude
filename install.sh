#!/bin/bash
# Install the hclaude sandbox wrapper as `claude`:
#   curl -fsSL https://raw.githubusercontent.com/monday-j/hclaude/main/install.sh | bash
# Rerunning it updates an existing install. Never uses sudo.
#
# Environment: HCLAUDE_REPO (git URL), HCLAUDE_DIR (checkout, default ~/.local/share/hclaude),
#              HCLAUDE_BIN (link, default ~/.local/bin/claude)

# Everything is inside main so a truncated download runs nothing.
main() {
  set -euo pipefail

  local repo="${HCLAUDE_REPO:-https://github.com/monday-j/hclaude.git}"
  local dest="${HCLAUDE_DIR:-$HOME/.local/share/hclaude}"
  local bin="${HCLAUDE_BIN:-$HOME/.local/bin/claude}"

  say() { echo "hclaude install: $*" >&2; }
  die() { say "$*"; exit 1; }

  # Dependencies: report, never install.
  if ! command -v rpm >/dev/null; then
    die "rpm not found. hclaude needs Fedora (or similar) with: git podman crun-krun libkrun>=1.8"
  fi
  local missing=() pkg
  for pkg in git podman crun-krun libkrun; do
    rpm -q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    die "missing packages. Install them with:
    sudo dnf install ${missing[*]}
then rerun this installer."
  fi
  local krun_ver
  krun_ver="$(rpm -q --qf '%{VERSION}' libkrun)"
  if [ "$(printf '%s\n%s\n' 1.8 "$krun_ver" | sort -V | head -n1)" != 1.8 ]; then
    die "libkrun $krun_ver is too old (need >= 1.8). Try: sudo dnf upgrade libkrun"
  fi

  # Fetch.
  if [ -d "$dest/.git" ]; then
    say "updating $dest"
    git -C "$dest" pull --ff-only
  elif [ -e "$dest" ]; then
    die "$dest exists but is not a git checkout; move it aside or set HCLAUDE_DIR."
  else
    say "cloning $repo into $dest"
    mkdir -p "$(dirname "$dest")"
    git clone "$repo" "$dest"
  fi

  # Link.
  local target="$dest/hclaude"
  mkdir -p "$(dirname "$bin")"
  if [ -e "$bin" ] || [ -L "$bin" ]; then
    if [ ! -L "$bin" ] || [ "$(readlink -f "$bin")" != "$(readlink -f "$target")" ]; then
      die "$bin already exists and is not this wrapper; remove it or set HCLAUDE_BIN."
    fi
  fi
  ln -sfn "$target" "$bin"
  say "linked $bin -> $target"
  case ":$PATH:" in
    *":$(dirname "$bin"):"*) ;;
    *) say "warning: $(dirname "$bin") is not on your PATH" ;;
  esac

  # krun smoke test: the guest should boot its own kernel. Not fatal.
  local guest_kernel
  if guest_kernel="$(podman run --runtime=krun --rm fedora:44 uname -r 2>/dev/null)" \
      && [ -n "$guest_kernel" ] && [ "$guest_kernel" != "$(uname -r)" ]; then
    say "krun OK (guest kernel $guest_kernel)"
  else
    say "warning: krun smoke test failed; the sandbox may not be a real microVM."
    say "  check: podman run --runtime=krun --rm fedora:44 uname -r   (should differ from: uname -r)"
  fi

  say "done. Run \`$(basename "$bin")\` in a project directory; the first run builds the image (a few minutes)."
}

main "$@"
