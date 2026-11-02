# ARM64 Linux From Scratch

Experimental, staged **native AArch64 LFS 12.4** build on standard public GitHub Actions ARM64 runners. CircleCI integration is postponed.

The current goal is a verified minimal rootfs that can later be tested separately under Termux/proot. This repository does **not** yet contain a complete bootable LFS or KDE build.

## Safety and scope

- Existing Arch/Termux installations are not part of this repository and must not be overwritten.
- Build stages must be reproducible and must stop at a completed step.
- Do not commit tokens, credentials, personal data, private archives, or device backups.
- CircleCI Free jobs can run for at most one hour, so later stages must persist finished outputs as artifacts or cache entries instead of restarting everything.

## Roadmap

1. **Probe:** confirm `aarch64`, record OS/CPU/memory/disk/tool availability.
2. **Prepare:** define an isolated build root, package versions, checksums, and download logic.
3. **Toolchain and minimal rootfs:** split work into resumable jobs and preserve completed outputs.
4. **Separate launch test:** test a minimal rootfs separately from the existing Termux Arch installation.
5. **Only then:** consider BLFS/KDE and the pink desktop customization.

## Stage 0: probe

The workflow in `.circleci/config.yml` uses a native Arm VM and runs `scripts/probe.sh`. It installs nothing and changes no persistent device state. The report is saved as a CircleCI artifact.

A report listing missing host tools is not a failed architecture probe; it is input for the next preparation stage. A non-ARM64 runner is a hard failure.

## Completed probe — 2026-11-01

[GitHub Actions run 41336216398](https://github.com/forcontact655-collab/arm64-lfs/actions/runs/41336216398) completed successfully on the standard public ARM64 runner:

- Native `aarch64`, Ubuntu 24.04.5 LTS.
- 4 CPUs and approximately 16 GB RAM.
- 107 GB free disk space at probe time.
- All 19 checked build tools found; `MISSING_TOOLS=none`.

The report was downloaded from the run artifact and verified locally. This completes only the environment probe; no LFS packages have been built yet.

## Stage 1: verified LFS 12.4 sources

The manually dispatched `lfs-sources` workflow downloads the official SysV source set into an isolated `$LFS/sources` directory and verifies every downloaded file against the official LFS 12.4 `md5sums`. It also generates SHA-256 sums for later checkpoints and stores the source directory in the GitHub Actions cache.

The upstream `wget-list-sysv` currently lists `dbus-1.16.2.tar.xz`, but that file is absent from both the LFS 12.4 book's package list and the official `md5sums`. The verified base-source stage skips it and records the skip; it is not needed for the base LFS book.

No packages are compiled in this stage, and no existing Termux/Arch installation is accessed.
