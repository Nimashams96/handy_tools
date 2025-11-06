#!/usr/bin/env bash
# g16_install_from_tbz.sh
#
# Installs Gaussian 16 from a .tbz tarball into a chosen g16root, fixes deps,
# runs Gaussian's installer, and appends PATH/ENV lines to ~/.bashrc.
#
# Defaults can be edited here and are overridable via CLI flags.

set -euo pipefail

############################
# User-tweakable defaults  #
############################
TAR_PATH_DEFAULT="$HOME/Downloads/G16-A03-AVX2.tbz"
G16ROOT_DEFAULT="$HOME/Programs/gaussian_16"
INSTALL_DEPS_DEFAULT=1   # set to 0 to skip apt deps by default

############################
# CLI parsing              #
############################
show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -t, --tar   PATH    Path to Gaussian 16 tarball (.tbz). Default: $TAR_PATH_DEFAULT
  -r, --root  PATH    Install root (parent of g16).     Default: $G16ROOT_DEFAULT
      --no-deps       Skip installing apt dependencies
  -h, --help          Show this help

Examples:
  $0 -t ~/Downloads/G16-A03-AVX2.tbz -r ~/Programs/gaussian_16
  $0 --no-deps
EOF
}

TAR_PATH="$TAR_PATH_DEFAULT"
G16ROOT="$G16ROOT_DEFAULT"
INSTALL_DEPS="$INSTALL_DEPS_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--tar)
      [[ $# -ge 2 ]] || { echo "Missing arg for $1"; exit 2; }
      TAR_PATH="$2"; shift 2;;
    -r|--root)
      [[ $# -ge 2 ]] || { echo "Missing arg for $1"; exit 2; }
      G16ROOT="$2"; shift 2;;
    --no-deps)
      INSTALL_DEPS=0; shift;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Unknown option: $1"; show_help; exit 2;;
  esac
done

############################
# Pre-flight               #
############################
echo "[g16] Tarball:  $TAR_PATH"
echo "[g16] g16root:  $G16ROOT"
mkdir -p "$G16ROOT"

if [[ ! -f "$TAR_PATH" ]]; then
  echo "[g16][ERROR] Tar file not found: $TAR_PATH"
  exit 1
fi

############################
# Dependencies            #
############################
DEPS=(csh tcsh gfortran libx11-6 libxt6 libxmu6)
if [[ "$INSTALL_DEPS" -eq 1 ]]; then
  if command -v apt >/dev/null 2>&1; then
    echo "[g16] Installing dependencies: ${DEPS[*]}"
    sudo apt update
    sudo apt install -y "${DEPS[@]}"
  else
    echo "[g16][WARN] 'apt' not found; install manually: ${DEPS[*]}"
  fi
else
  echo "[g16] Skipping dependency installation (--no-deps)"
fi

############################
# Extract tarball         #
############################
echo "[g16] Extracting: $TAR_PATH -> $G16ROOT"
tar xvjf "$TAR_PATH" -C "$G16ROOT"

if [[ ! -d "$G16ROOT/g16" ]]; then
  echo "[g16][ERROR] Expected directory after extraction: $G16ROOT/g16"
  exit 1
fi

############################
# Scratch + profile       #
############################
export GAUSS_SCRDIR="$G16ROOT/scr"
mkdir -p "$GAUSS_SCRDIR"
chmod 700 "$GAUSS_SCRDIR"

PROFILE="$G16ROOT/g16/bsd/g16.profile"
if [[ ! -f "$PROFILE" ]]; then
  echo "[g16][ERROR] Missing profile: $PROFILE"
  exit 1
fi

# Load env for this shell so installer can see it
export g16root="$G16ROOT"
# shellcheck disable=SC1090
. "$PROFILE"

############################
# Fix execs + run install #
############################
pushd "$G16ROOT/g16" >/dev/null
chmod +x g16 l*.exe formchk cubegen newzmat unfchk chkchk 2>/dev/null || true
echo "[g16] Running ./bsd/install"
./bsd/install
popd >/dev/null

############################
# Update ~/.bashrc        #
############################
BASHRC="$HOME/.bashrc"
echo "[g16] Updating $BASHRC PATH/ENV block"

# Convert $G16ROOT to a tilde form if under $HOME for pretty rc lines
if [[ "$G16ROOT" == "$HOME"* ]]; then
  RC_ROOT="~${G16ROOT#$HOME}"
else
  RC_ROOT="$G16ROOT"
fi

# Remove any previous simple 3-line block starting with '# Gaussian 16'
# and the next two lines to avoid duplicates.
if [[ -f "$BASHRC" ]]; then
  awk '
    BEGIN{skip=0}
    /^# Gaussian 16$/ {skip=3; next}
    { if (skip>0) {skip--; next} else {print} }
  ' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
fi

cat >> "$BASHRC" <<EOF
# Gaussian 16
export GAUSS_EXEDIR=$RC_ROOT/g16
export GAUSS_SCRDIR=$RC_ROOT/scr
export PATH=$RC_ROOT/g16:\$PATH
EOF

echo "[g16] Appended PATH/ENV lines. Reload with: source \"$BASHRC\""

############################
# Sanity hints            #
############################
echo "[g16] GAUSS_EXEDIR now (this shell): ${GAUSS_EXEDIR:-"(set after new shell)"}"
echo "[g16] Done."

