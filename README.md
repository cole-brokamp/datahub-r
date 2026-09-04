# datahub-r

`datahub-r` is a portable R 4.6.1 environment for CCHMC SQL Server work.
It combines a multi-architecture OCI image with a small standalone Rust command that runs the same environment on a laptop, workstation, or cluster.
The repository name describes the shared DataHub environment, while database profiles keep it from being tied to only the MBHI database.

The first release is `2026.09.0`, with native CLI archives and a digest-pinned Linux ARM64/AMD64 image published through GitHub.

## What is portable

The released `datahub-r` command is a native executable with no Rust, `just`, local R, or R package-manager dependency.
It automatically chooses Apple container, Docker, Podman, or Apptainer and supplies the runtime-specific arguments.
The release workflow builds executables for macOS and Linux on both ARM64 and AMD64.

The OCI image is also built for Linux ARM64 and AMD64.
It includes:

- R 4.6.1 from Posit's Ubuntu 24.04 build
- Microsoft ODBC Driver 18.6.2.1
- unixODBC and its development headers
- `needenv` 0.1.0, `DBI`, `odbc`, `dplyr`, `dbplyr`, `nanoparquet`, `bit64`, `pak`, and `renv`

The image starts from the fully specified `posit/r-base:4.6.1-noble` tag.
The R patch version is fixed, but there is intentionally no base-image digest because Posit may rebuild the tag with operating-system or security updates.
Every accepted rebuild receives a new `datahub-r` version even when the R version is unchanged.

## Installation

### Direct installer

The installer downloads the correct native executable for macOS or Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/cole-brokamp/datahub-r/main/install.sh | sh
```

The installer downloads the matching release archive, verifies its SHA-256 checksum, and places `datahub-r` in `${DATAHUB_R_INSTALL_DIR:-$HOME/.local/bin}`.
Use a particular immutable version with `--version`:

```sh
curl -fsSL https://raw.githubusercontent.com/cole-brokamp/datahub-r/main/install.sh \
  | sh -s -- --version 2026.09.0
```

Ensure `$HOME/.local/bin` is on `PATH` when using the default location.
The native executable does not require Rust, R, or a package manager, but it does require one supported container runtime.

### Manual release download

Every [GitHub release](https://github.com/cole-brokamp/datahub-r/releases) includes archives for Linux and macOS on both AMD64 and ARM64, along with a `SHA256SUMS` file.
For an x86_64 Linux workstation or cluster:

```sh
version=2026.09.0
curl -fLO "https://github.com/cole-brokamp/datahub-r/releases/download/v${version}/datahub-r-x86_64-unknown-linux-musl.tar.gz"
curl -fLO "https://github.com/cole-brokamp/datahub-r/releases/download/v${version}/SHA256SUMS"
sha256sum --check --ignore-missing SHA256SUMS
tar -xzf datahub-r-x86_64-unknown-linux-musl.tar.gz
install -m 0755 datahub-r "$HOME/.local/bin/datahub-r"
```

The other release targets are `aarch64-unknown-linux-musl`, `aarch64-apple-darwin`, and `x86_64-apple-darwin`.

### Homebrew

A Homebrew formula is attached to each release, but a tap is not yet configured.
After a tap is available, Homebrew will select the native executable for the host architecture and will not install a container runtime automatically.

### From a source checkout

Developers with Rust installed can build and install directly:

```sh
cargo install --path .
```

The optional `just install` recipe builds an optimized binary and copies it to `$HOME/.local/bin`.
Neither method is needed by users who install a released binary.

## Runtime setup

Install one supported runtime separately:

| Host | Recommended runtime | Other supported runtimes |
| --- | --- | --- |
| macOS | Apple container | Docker, Podman, Apptainer |
| Linux workstation | Docker | Podman, Apptainer |
| Linux cluster | Apptainer | Docker or Podman when permitted |

Automatic selection prefers Apple container on macOS, Docker on an ordinary Linux host, and Apptainer inside a Slurm, LSF, or PBS job.
Override selection with `--runtime` or `DATAHUB_R_RUNTIME`.

```sh
datahub-r --runtime podman Rscript analysis.R
export DATAHUB_R_RUNTIME=apptainer
```

Inspect the detected runtimes, selected image, cache locations, and host architecture with:

```sh
datahub-r doctor
```

The command loads the `apptainer/1.4.2` environment module when Apptainer is not already on `PATH` and the module command is available.
It never loads cluster R or MSSQL modules.

The published image can be prepared before a job starts with `datahub-r pull`.
Public GHCR pulls do not require registry authentication.

## Commands

Start interactive R in the current directory:

```sh
datahub-r
```

Run a script:

```sh
datahub-r Rscript analysis.R
```

Select a database profile for a check or script:

```sh
datahub-r --db OMOP check
datahub-r --db OMOP Rscript analysis.R
```

The profile defaults to `MBHI`, so `datahub-r check` uses the existing MBHI behavior.

Pass ordinary R arguments:

```sh
datahub-r R --quiet
datahub-r --quiet
```

The complete command set is:

```text
datahub-r [--runtime NAME] [--db PROFILE] [--env NAME ...] R [arguments]
datahub-r [--runtime NAME] [--db PROFILE] [--env NAME ...] Rscript SCRIPT [arguments]
datahub-r [--runtime NAME] [--db PROFILE] check
datahub-r [--runtime NAME] [--db PROFILE] shell [arguments]
datahub-r [--runtime NAME] pull
datahub-r doctor
datahub-r version
datahub-r help
```

## Image selection

A released executable embeds the immutable digest of the image built for that release.
Run `datahub-r version` to see both the CLI version and embedded image reference.
The executable therefore continues to use exactly its released image even if a human-readable registry tag changes.

Override the image for local development or testing:

```sh
export DATAHUB_R_IMAGE=datahub-r:local
export DATAHUB_R_IMAGE=/absolute/path/to/datahub-r.sif
```

A local SIF requires Apptainer.
An OCI reference works with any supported runtime and is converted to a cached SIF when Apptainer is selected.
`DATAHUB_R_PLATFORM=linux/amd64` can explicitly select an image platform when testing across architectures.

The unreleased source tree contains a deliberate image placeholder.
An executable built without the release workflow fails clearly unless `DATAHUB_R_IMAGE` is set.

## Posit Package Manager

The only default CRAN repository is the Noble Linux repository in Posit Public Package Manager:

```text
https://packagemanager.posit.co/cran/__linux__/noble/latest
```

The same repository is used to build the image and for packages installed by a user.
The image configures the R HTTP user agent needed for compatible Linux packages.
The dependency lock records PPM URLs and checksums for the complete baked dependency graph.

A project `.Rprofile` or explicit R code can replace `options("repos")` because R is programmable.
`datahub-r check` warns when the active CRAN repository is not the supported PPM repository.

## Persistent user packages

Packages baked into the image are read-only.
Packages installed normally by a user go into this container path:

```text
/home/datahub-r/.local/share/datahub-r/v1/R-4.6/library
```

Apple container, Docker, and Podman mount a persistent host data directory at `/home/datahub-r/.local/share/datahub-r`.
The host directory defaults to `${XDG_DATA_HOME:-$HOME/.local/share}/datahub-r` and can be changed with `DATAHUB_R_DATA_DIR`.
Apptainer uses the invoking user's bound home directory, so the corresponding `~/.local/share/datahub-r` directory persists directly.

The library is created and placed first in `.libPaths()` whenever R starts.
This behavior means:

- `install.packages("foo")` persists across subsequent runs;
- installing `DBI` or another baked package creates a user copy that shadows the image copy;
- removing the user copy reveals the baked fallback again; and
- a project `.Rprofile` can deliberately replace `.libPaths()` for expert use.

The `v1` directory is a library compatibility epoch.
A later image can advance it if system-library changes make existing compiled packages incompatible.
This epoch is independent of the release version.

## Credentials and other environment variables

Every database profile owns a separate set of names:

```text
<PROFILE>_DB_HOST
<PROFILE>_DB_NAME
<PROFILE>_DB_USERNAME
<PROFILE>_DB_PASSWORD
```

The profile is uppercased and must contain only letters, numbers, and underscores.
`DB_NAME` is optional and defaults to the profile name.
The other three values are required when a connection is made.
Define complete sets for different databases rather than relying on implicit cross-profile fallbacks.

There are two supported credential workflows.

### Project `.Renviron`

Create `.Renviron` in the directory where `datahub-r` will start:

```text
MBHI_DB_HOST=...
MBHI_DB_NAME=MBHI
MBHI_DB_USERNAME=...
MBHI_DB_PASSWORD=...

OMOP_DB_HOST=...
OMOP_DB_NAME=OMOP
OMOP_DB_USERNAME=...
OMOP_DB_PASSWORD=...
```

Protect it with:

```sh
chmod 600 .Renviron
```

The command binds the current directory and starts R there.
R reads the file through its normal startup process, while `datahub-r` does not parse or copy it.

### Exported variables

Credentials can instead be exported before the command:

```sh
export MBHI_DB_HOST=...
export MBHI_DB_NAME=MBHI
export MBHI_DB_USERNAME=...
export MBHI_DB_PASSWORD=...
datahub-r check
```

The launcher forwards only the four names for the selected profile.
Secret values remain in the process environment and are never placed in runtime arguments.

Forward another exported variable by name:

```sh
export MY_SETTING=value
datahub-r --env MY_SETTING Rscript analysis.R
```

Use `--env NAME`, not `--env NAME=value`.
Name-value arguments are rejected to keep secrets out of process listings and shell history.

Apptainer runs with `--cleanenv` and clears inherited `APPTAINERENV_*` and `SINGULARITYENV_*` variables before creating its explicit forwarding environment.
This prevents host R libraries, compiler settings, module paths, or stale forwarding variables from leaking into the container.

When the shell and project `.Renviron` both define a variable, `.Renviron` wins because R processes it after the container process environment is set.
The clean environment does not isolate the filesystem because the current project and persistent package directory must remain accessible.

## Connection check

Run:

```sh
datahub-r check
```

The check verifies the R version, baked packages, PPM setting, user library, and ODBC Driver 18 registration.
Normal R startup loads the shared database helper, so scripts can connect using the profile selected by `--db`:

```r
con <- datahub_connect()
```

Pass a profile directly with `datahub_connect("OMOP")` when needed.
The function returns an ordinary DBI connection and does not disconnect it automatically.
Call `DBI::dbDisconnect(con)` when the work is complete.
The lower-level `datahub_r_database_config()` helper returns an object with `profile`, `host`, `database`, `username`, and `password` fields regardless of the environment-variable prefix.
The checker connects with encryption and the existing trusted-certificate behavior, runs `SELECT 1 AS ok`, and disconnects on exit.
It never prints credential values or a reconstructed connection string.

Interactive R and arbitrary scripts do not require database credentials.
The preflight runs only for `datahub-r check` or when user code calls it.

## Apptainer image cache

Remote OCI images used with Apptainer are converted to SIF and cached in this order:

1. `DATAHUB_R_CACHE_DIR`
2. `/scratch/$USER/datahub-r` when available and writable
3. `${XDG_CACHE_HOME:-$HOME/.cache}/datahub-r`

The cache has separate final-image, Apptainer cache, temporary-conversion, partial-download, and pull-lock directories.
The image reference and architecture are part of the cached filename identity.
A per-reference lock serializes concurrent first runs, and the winning pull atomically moves its completed SIF into place.
Credentials and project data are never stored in the image cache.
On an interactive cache miss, `datahub-r` prints one status line while Apptainer runs in silent mode; conversion errors are still reported.

OCI runtimes use their own native image stores instead of this SIF cache.
Use `datahub-r pull` to prepare the configured image without starting R.

## Versioning and updates

`datahub-r` uses calendar versions in the form `YYYY.MM.REVISION`.
The year and month identify the release month, while `REVISION` starts at zero and increments for every additional accepted release in that month.
The month is zero-padded so versions sort naturally and remain visually consistent.
For example, the first September 2026 release is `2026.09.0`, a later security rebuild that month is `2026.09.1`, and the first October release is `2026.10.0`.
The `-dev` suffix is used only for unreleased work.

`VERSION` is the sole authority for the calendar version.
The build reads it into the CLI, OCI tag, image metadata, release archives, and generated Homebrew formula.
A release uses these identifiers:

```text
VERSION:         2026.09.0
Git tag:         v2026.09.0
OCI tag:         ghcr.io/cole-brokamp/datahub-r:2026.09.0
Embedded image:  docker://ghcr.io/cole-brokamp/datahub-r@sha256:7d75e64f1fdac93c809e804e21b6fef8540fe005fbc65336bb6ee8b7e7323b85
```

The Git and OCI tags are human-readable immutable release names.
The native executable embeds the multi-architecture image manifest digest, so an installed version and its container cannot drift apart.
There is no automatic update check and the default command never follows `latest`.
If a release workflow is retried after its OCI tag exists, it reuses that tag's existing digest instead of rebuilding or moving the tag.

Any change to distributed image contents receives a new calendar version, including a rebuild made only for operating-system or base-image security updates.
Package or driver updates also receive a new version and are recorded in the dependency lock or pinned build arguments.
If a change makes existing compiled user packages unsafe to reuse, advance the separate user-library compatibility epoch in addition to issuing a new calendar version.

To make a release, remove `-dev` from `VERSION`, commit that value, and push the matching `vYYYY.MM.REVISION` tag after review.
The release workflow then builds and pushes the Linux ARM64 and AMD64 image under one OCI tag, captures its manifest digest, compiles four native CLI archives with that digest embedded, writes checksums, creates the GitHub release, and generates a Homebrew formula.
If `HOMEBREW_TAP_TOKEN` is configured, the final job updates `cole-brokamp/homebrew-tap`; otherwise it reports that the tap update was skipped.

For the next development cycle, change `VERSION` to the next intended calendar version with `-dev`.
Do not reuse or move an existing Git or OCI release tag.

## Local development

Run the CLI checks with Cargo and the shell test harnesses:

```sh
cargo fmt -- --check
cargo test
cargo build
bash tests/test-static.sh
bash tests/test-cli.sh target/debug/datahub-r
bash tests/test-installer.sh target/debug/datahub-r
bash tests/test-release-packaging.sh target/debug/datahub-r
```

The optional `just test-static` recipe runs the same sequence.

Build the native-architecture OCI image with Apple container:

```sh
just build
```

Override the build platform when cross-architecture emulation is configured:

```sh
DATAHUB_R_PLATFORM=linux/amd64 just build
```

Build and run the image checks with `just test-image`, or run every local check with `just test`.
The image tests verify R, PPM, packages, Driver 18, project startup files, persistent package installation, package shadowing, fallback to a baked package after the user copy is removed, and the absence of project `.Renviron` files or credential-shaped fixtures from every OCI layer.
Automated tests do not contact MBHI.

## Cluster acceptance

No artifact should be copied to the cluster without explicit approval.
When an approved SIF is available there, acceptance consists of:

1. Run `datahub-r check` for MBHI with a protected project `.Renviron`.
2. Repeat the MBHI check with exported variables and no `.Renviron`.
3. Verify the live `SELECT 1` result.
4. Run `datahub-r --db OMOP check` once an OMOP profile is configured.
5. Install and reload a harmless PPM package in the persistent library.
6. Confirm that neither the R nor MSSQL cluster module was loaded.

## Release status

The public repository is [cole-brokamp/datahub-r](https://github.com/cole-brokamp/datahub-r).
Release `v2026.09.0` is the first published release, and its multi-architecture image is pinned to the manifest digest shown above.
The Homebrew tap is not yet configured.
Cluster acceptance and live database checks remain separate from the automated build and require credentials available only in the target environment.
