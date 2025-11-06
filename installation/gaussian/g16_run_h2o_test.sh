#!/usr/bin/env bash
# g16_run_h2o_test.sh
# Runs a Gaussian 16 smoke test (H2O molecule)
# Accepts CLI args for g16root and test directory.
#
# Usage:
#   ./g16_run_h2o_test.sh [-r|--root <g16root>] [-d|--dir <test_dir>]
#
# Defaults:
#   g16root = $HOME/Programs/gaussian_16
#   test_dir = $HOME/Desktop/test_g16

set -euo pipefail

############################
# Defaults
############################
G16ROOT_DEFAULT="$HOME/Programs/gaussian_16"
TEST_DIR_DEFAULT="$HOME/Desktop/test_g16"

############################
# CLI parsing
############################
show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -r, --root   PATH    Gaussian 16 root path. Default: $G16ROOT_DEFAULT
  -d, --dir    PATH    Directory to run test in. Default: $TEST_DIR_DEFAULT
  -h, --help           Show this help and exit

Example:
  $0 -r ~/Programs/gaussian_16 -d ~/Desktop/test_g16
EOF
}

G16ROOT="$G16ROOT_DEFAULT"
TEST_DIR="$TEST_DIR_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--root)
      [[ $# -ge 2 ]] || { echo "Missing argument for $1"; exit 2; }
      G16ROOT="$2"; shift 2;;
    -d|--dir)
      [[ $# -ge 2 ]] || { echo "Missing argument for $1"; exit 2; }
      TEST_DIR="$2"; shift 2;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Unknown option: $1"; show_help; exit 2;;
  esac
done

############################
# Env setup
############################
if [[ ! -d "$G16ROOT/g16" ]]; then
  echo "[g16][ERROR] Invalid g16root: $G16ROOT"
  exit 1
fi

if [[ ! -f "$G16ROOT/g16/bsd/g16.profile" ]]; then
  echo "[g16][ERROR] Missing $G16ROOT/g16/bsd/g16.profile"
  exit 1
fi

echo "[g16] Using Gaussian root: $G16ROOT"
echo "[g16] Using test directory: $TEST_DIR"

# Load Gaussian environment for this shell
export g16root="$G16ROOT"
# shellcheck disable=SC1090
. "$G16ROOT/g16/bsd/g16.profile"

export GAUSS_SCRDIR="$G16ROOT/scr"
mkdir -p "$GAUSS_SCRDIR"
chmod 700 "$GAUSS_SCRDIR"

############################
# Prepare test directory
############################
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

cat > h2o.com <<'EOF'
%mem=1GB
%nprocshared=2
# hf/6-31g(d) scf=tight

water test

0 1
O
H 1 0.96
H 1 0.96 2 104.5
EOF

############################
# Run Gaussian test
############################
echo "[g16] Running Gaussian 16 on h2o.com..."
g16 < h2o.com > h2o.log

echo "----- tail h2o.log -----"
tail -n 40 h2o.log || true
echo "------------------------"

if grep -q "Normal termination of Gaussian 16" h2o.log; then
  echo "[g16] ✅ Success: Normal termination detected."
  echo "[g16] Output log: $TEST_DIR/h2o.log"
  exit 0
else
  echo "[g16][WARN] Gaussian did not terminate normally."
  echo "[g16] Check: $TEST_DIR/h2o.log"
  exit 2
fi

