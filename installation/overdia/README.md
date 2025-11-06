# Overdia Installer

This directory contains `overdia_install_from_tgz.sh`, a helper script that
automates unpacking and building an Overdia release archive (`.tgz`) on Debian
or Ubuntu systems. The script will discover the source directory, patch the
bundled `Makefile` with sane defaults, install required build dependencies, and
optionally update your shell `PATH` so the resulting `overdia-par.e` binary is
easy to run.

## Prerequisites
- Bash (the script uses `#!/usr/bin/env bash`).
- A `*.tgz` package that contains the Overdia sources.
- `sudo` access on a Debian/Ubuntu machine: the script uses `apt-get` to install
  build dependencies such as `gfortran`, BLAS/LAPACK (or Intel MKL), `make`, and
  OpenMP.
- Enough disk space in the chosen extraction directory (defaults to
  `~/Programs/overdia_1`).

## Quick Start
From the root of this repository (or any directory you prefer), run:

```bash
bash installation/overdia/overdia_install_from_tgz.sh --tgz /path/to/overdia.tgz
```

The script ships with a shebang (`#!/usr/bin/env bash`), so you can also make it
executable and run it directly:

```bash
chmod +x installation/overdia/overdia_install_from_tgz.sh
./installation/overdia/overdia_install_from_tgz.sh --tgz /path/to/overdia.tgz
```

This will:
1. Create the destination directory (defaults to `~/Programs/overdia_1`).
2. Extract the archive.
3. Locate the Overdia source tree and patch its `Makefile`.
4. Install GNU build dependencies via `apt-get`.
5. Compile the code with `make -j$(nproc)`.
6. Append the detected source directory to your `PATH` in `~/.bashrc`.

After the run completes, reload your shell (`source ~/.bashrc`) and try:

```bash
overdia-par.e -h
```

## Command-Line Options
```
Usage: overdia_install_from_tgz.sh --tgz PATH [options]

Required:
  --tgz PATH            Path to the Overdia .tgz file to unpack and build.

Optional:
  --dest DIR            Override the extraction directory (default: ~/Programs/overdia_1).
  --use-mkl             Install Intel oneAPI MKL and build with MKL libraries.
  --install-symlink     Symlink the compiled binary to ~/.local/bin/<name>.
  --install-bashrc      Append the source directory to PATH in ~/.bashrc (default).
  --install-none        Skip PATH updates and symlink creation.
  --name NAME           Command name used for the symlink (default: overdia).
  --jobs N              Number of parallel build jobs (default: nproc).
  -h, --help            Display inline help.
```

## Installation Modes
- `--install-bashrc` (default): Adds the absolute path to the source directory
  into your `~/.bashrc`. Reload the shell or run `source ~/.bashrc` to pick up
  the change.
- `--install-symlink`: Creates `~/.local/bin/<name>` (default `overdia`) that
  points to the built binary, and ensures `~/.local/bin` is on your `PATH`.
- `--install-none`: Leaves your `PATH` untouched—you can run the binary
  directly from the build directory.

## Notes
- The script backs up the original `Makefile` as
  `Makefile.bak.<timestamp>` before applying changes such as forcing `gfortran`
  and setting `FFLAGS := -O2 -std=legacy`.
- If MKL is requested, the script installs `intel-oneapi-mkl` along with the
  necessary runtime libraries; otherwise it falls back to GNU BLAS/LAPACK.
- Use `--install-none` if you prefer to manage environment setup manually.
- You can rerun the script with a different destination or install mode; only
  the newly extracted source tree is touched.

For more details, inspect the script itself:
`installation/overdia/overdia_install_from_tgz.sh`.
