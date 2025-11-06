# Gaussian Utilities

Helper scripts for installing Gaussian 16 and running a quick smoke test to confirm the installation. These tools assume you already possess a licensed Gaussian 16 `.tbz` distribution archive.

## Scripts

- `g16_install_from_tbz.sh` – Automates extraction and setup of Gaussian 16 from a `.tbz` tarball, installs common Linux dependencies, runs the vendor-provided installer, and appends the required environment variables to `~/.bashrc`.
- `g16_run_h2o_test.sh` – Creates a minimal working directory, prepares an H₂O Hartree–Fock input deck, and executes `g16` to verify that the installation terminates normally.

## Installation Helper (`g16_install_from_tbz.sh`)

```bash
./g16_install_from_tbz.sh [--tar PATH] [--root PATH] [--no-deps]
```

- `--tar PATH` (`-t`) – Path to the Gaussian tarball. Defaults to `~/Downloads/G16-A03-AVX2.tbz`.
- `--root PATH` (`-r`) – Destination directory that will contain the `g16` folder. Defaults to `~/Programs/gaussian_16`.
- `--no-deps` – Skip installing the prerequisite packages (`csh`, `tcsh`, `gfortran`, `libx11-6`, `libxt6`, `libxmu6`).

What the script does:

1. Validates the tarball path and creates the target `g16root`.
2. Optionally installs the listed dependencies via `apt`.
3. Extracts the tarball under the chosen root and runs `g16/bsd/install`.
4. Creates a scratch directory at `<root>/scr`.
5. Adds a `# Gaussian 16` block to `~/.bashrc` that exports `GAUSS_EXEDIR`, `GAUSS_SCRDIR`, and prepends `g16` to `PATH`.

After running the script, open a new shell (or `source ~/.bashrc`) so the environment picks up the new settings.

## Smoke Test (`g16_run_h2o_test.sh`)

```bash
./g16_run_h2o_test.sh [--root PATH] [--dir PATH]
```

- `--root PATH` (`-r`) – Location of the `g16` installation. Defaults to `~/Programs/gaussian_16`.
- `--dir PATH` (`-d`) – Working directory for the test job. Defaults to `~/Desktop/test_g16`.

The script performs the following steps:

1. Loads Gaussian’s environment (`g16.profile`) from the requested root and ensures the scratch directory exists.
2. Creates `h2o.com`, a simple Hartree–Fock/6-31G(d) water molecule input file, in the test directory.
3. Runs `g16 < h2o.com > h2o.log`, tails the final portion of the log, and reports success when “Normal termination of Gaussian 16” is detected.

Use this script after installation to verify that executables launch correctly and that environment variables are properly configured.

## Quick Start

1. Install Gaussian 16:
   ```bash
   ./g16_install_from_tbz.sh -t /path/to/G16-XXXX.tbz -r ~/Programs/gaussian_16
   ```
2. Reload your shell environment:
   ```bash
   source ~/.bashrc
   ```
3. Run the smoke test:
   ```bash
   ./g16_run_h2o_test.sh
   ```

The test log will be available at the chosen test directory (default `~/Desktop/test_g16/h2o.log`).
