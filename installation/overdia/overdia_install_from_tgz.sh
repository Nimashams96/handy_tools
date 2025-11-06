#!/usr/bin/env bash
# install_overdia_from_tgz.sh
# Decompresses a .tgz into a destination, finds the source dir, patches Makefile,
# installs dependencies, builds Overdia, and updates PATH (default via ~/.bashrc).

set -euo pipefail

# Defaults
TGZ=""
DEST="${HOME}/Programs/overdia_1"
USE_MKL="no"                      # "yes" to use MKL; otherwise GNU BLAS/LAPACK
INSTALL_MODE="bashrc"             # default as requested: "bashrc" | "symlink" | "none"
INSTALL_NAME="overdia"            # only used for symlink mode
JOBS="$(nproc)"

usage() {
  cat <<EOF
Usage: $0 --tgz PATH [options]

Required:
  --tgz PATH            Path to overdia .tgz file

Optional:
  --dest DIR            Extraction destination (default: ${HOME}/Programs/overdia_1)
  --use-mkl             Use Intel MKL instead of GNU BLAS/LAPACK (default: off)
  --install-symlink     Symlink built binary to ~/.local/bin/\$INSTALL_NAME
  --install-bashrc      Add the detected source directory to PATH in ~/.bashrc (default)
  --install-none        Do not modify PATH or symlink
  --name NAME           Command name when symlinking (default: overdia)
  --jobs N              Parallel build jobs (default: $(nproc))
  -h, --help            Show this help

Examples:
  $0 --tgz ./overdia-1.0.tgz
  $0 --tgz ./overdia-1.0.tgz --dest "\$HOME/Programs/overdia_1"
  $0 --tgz ./overdia.tgz --use-mkl --install-symlink --name overdia
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tgz) TGZ="$2"; shift 2;;
    --dest) DEST="$2"; shift 2;;
    --use-mkl) USE_MKL="yes"; shift;;
    --install-symlink) INSTALL_MODE="symlink"; shift;;
    --install-bashrc) INSTALL_MODE="bashrc"; shift;;
    --install-none) INSTALL_MODE="none"; shift;;
    --name) INSTALL_NAME="$2"; shift 2;;
    --jobs) JOBS="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

# Validate inputs
if [[ -z "${TGZ}" ]]; then
  echo "ERROR: --tgz PATH is required." >&2
  usage
  exit 1
fi
if [[ ! -f "${TGZ}" ]]; then
  echo "ERROR: tgz not found: ${TGZ}" >&2
  exit 1
fi

# Prep destination and extract
echo "==> Creating destination: ${DEST}"
mkdir -p "${DEST}"

echo "==> Extracting ${TGZ} -> ${DEST}"
tar -xzf "${TGZ}" -C "${DEST}"

# Try to detect the source directory
# 1) If ${DEST}/source exists and has a Makefile, use it
# 2) Else search within DEST for a Makefile that likely belongs to Overdia
SRC_DIR=""

if [[ -f "${DEST}/source/Makefile" ]]; then
  SRC_DIR="${DEST}/source"
else
  # Find candidate Makefiles within a reasonable depth
  mapfile -t CANDIDATES < <(find "${DEST}" -maxdepth 4 -type f -name "Makefile" 2>/dev/null || true)

  # Prefer a Makefile that mentions 'overdia-par.e' or obvious objects
  for mk in "${CANDIDATES[@]:-}"; do
    if grep -Eq 'overdia-par\.e|overdia\.o|fragdiab\.o' "$mk"; then
      SRC_DIR="$(dirname "$mk")"
      break
    fi
  done

  # Fallback to first Makefile found
  if [[ -z "${SRC_DIR}" && ${#CANDIDATES[@]:-0} -gt 0 ]]; then
    SRC_DIR="$(dirname "${CANDIDATES[0]}")"
  fi
fi

if [[ -z "${SRC_DIR}" || ! -f "${SRC_DIR}/Makefile" ]]; then
  echo "ERROR: Could not locate Overdia source Makefile under ${DEST}" >&2
  exit 1
fi

echo "==> Detected source directory: ${SRC_DIR}"

# Install dependencies
echo "==> Installing build dependencies"
sudo apt-get update
if [[ "${USE_MKL}" == "yes" ]]; then
  sudo apt-get install -y gfortran make libiomp5 intel-oneapi-mkl
else
  sudo apt-get install -y gfortran make libblas-dev liblapack-dev libomp-dev
fi

# Patch Makefile
MK="${SRC_DIR}/Makefile"
BK="${SRC_DIR}/Makefile.bak.$(date +%s)"
cp "${MK}" "${BK}"
echo "==> Backed up Makefile -> ${BK}"

echo "==> Patching Makefile"
# Force gfortran
sed -i 's/^[[:space:]]*FC[[:space:]]*:=.*/FC := gfortran/' "${MK}"

# Select libs
if [[ "${USE_MKL}" == "yes" ]]; then
  sed -i 's/^[[:space:]]*USE_LIBS[[:space:]]*:=.*/USE_LIBS := mkl/' "${MK}"
else
  sed -i 's/^[[:space:]]*USE_LIBS[[:space:]]*:=.*/USE_LIBS := gnu/' "${MK}"
fi

# Ensure parallel yes if variable exists
if grep -q '^[[:space:]]*PARALLEL[[:space:]]*:=' "${MK}"; then
  sed -i 's/^[[:space:]]*PARALLEL[[:space:]]*:=.*/PARALLEL := yes/' "${MK}"
fi

# Add FFLAGS if missing
if ! grep -q '^[[:space:]]*FFLAGS[[:space:]]*:=' "${MK}"; then
  awk '
    BEGIN{done=0}
    {
      print $0
      if (!done && $0 ~ /^[ \t]*FC[ \t]*:=/) {
        print "FFLAGS := -O2 -std=legacy"
        done=1
      }
    }' "${MK}" > "${MK}.tmp" && mv "${MK}.tmp" "${MK}"
  echo "==> Added FFLAGS := -O2 -std=legacy"
fi

# Ensure .f90 rule compiles without passing LIBS at compile time
if grep -q '^\s*%.o:\s*%.f90' "${MK}"; then
  awk '
    BEGIN{state=0}
    {
      if (state==0 && $0 ~ /^[ \t]*%.o:[ \t]*%.f90/) {
        print $0
        getline                           # drop the old compile command
        print "\t$(FC) $(FFLAGS) $(PARFLAG) -c $<"
        state=1
      } else {
        print $0
      }
    }' "${MK}" > "${MK}.tmp" && mv "${MK}.tmp" "${MK}"
fi

# Update MAT1.o and EIGEN.o compile lines to use FFLAGS
sed -i 's/^\([[:space:]]*MAT1\.o:.*\)\n[[:space:]]*$(FC)[^$]*$/\1\n\t$(FC) $(FFLAGS) -c $</' "${MK}" || true
sed -i 's/^\([[:space:]]*EIGEN\.o:.*\)\n[[:space:]]*$(FC)[^$]*$/\1\n\t$(FC) $(FFLAGS) -c $</' "${MK}" || true

# Safer clean rule
if grep -q '^clean:' "${MK}"; then
  awk '
    BEGIN{in_clean=0}
    {
      if ($0 ~ /^clean:/) {in_clean=1; print $0; next}
      if (in_clean==1) {
        print "\trm -f $(objects) overdia-par.e"
        in_clean=2
        next
      }
      print $0
    }' "${MK}" > "${MK}.tmp" && mv "${MK}.tmp" "${MK}"
fi

echo "==> Makefile patched"

# Build
echo "==> Building Overdia"
make -C "${SRC_DIR}" -j"${JOBS}"

BIN="${SRC_DIR}/overdia-par.e"
if [[ ! -x "${BIN}" ]]; then
  echo "ERROR: Build did not produce ${BIN}" >&2
  exit 1
fi

echo "==> Build success: ${BIN}"

# Install modes
if [[ "${INSTALL_MODE}" == "symlink" ]]; then
  mkdir -p "${HOME}/.local/bin"
  ln -sf "$(realpath "${BIN}")" "${HOME}/.local/bin/${INSTALL_NAME}"
  echo "==> Symlinked to ${HOME}/.local/bin/${INSTALL_NAME}"
  if ! echo "${PATH}" | grep -q "${HOME}/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
    echo "==> Added ~/.local/bin to PATH in ~/.bashrc"
  fi
elif [[ "${INSTALL_MODE}" == "bashrc" ]]; then
  ABS_SRC="$(realpath "${SRC_DIR}")"
  if ! grep -Fq "${ABS_SRC}" "${HOME}/.bashrc"; then
    echo "export PATH=\"\$PATH:${ABS_SRC}\"" >> "${HOME}/.bashrc"
    echo "==> Appended ${ABS_SRC} to PATH in ~/.bashrc"
  else
    echo "==> PATH already includes ${ABS_SRC} in ~/.bashrc"
  fi
else
  echo "==> Skipping PATH/symlink modifications (install-none)"
fi

echo "==> Done."
echo "Try: ${BIN} -h"
if [[ "${INSTALL_MODE}" == "symlink" ]]; then
  echo "Or: ${INSTALL_NAME} -h"
elif [[ "${INSTALL_MODE}" == "bashrc" ]]; then
  echo "Reload your shell or: source ~/.bashrc; then run: overdia-par.e -h"
fi
