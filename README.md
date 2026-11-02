# ARM64 Linux From Scratch

Experimental, staged **native AArch64 LFS 12.4** build. Current workflows run on standard public GitHub Actions ARM64 runners; CircleCI API access is available if a later stage needs migration.

The current checkpoint is a verified minimal rootfs for a separate Termux/proot launch test. This repository does **not** yet contain a complete bootable LFS or KDE build.

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

## Completed chapter 5 toolchain — 2026-11-02

[GitHub Actions run 41412569250](https://github.com/forcontact655-collab/arm64-lfs/actions/runs/41412569250) completed successfully. The ARM64 GCC multi-os directory was corrected to `../lib`; the report verified `LIBSTDCXX=present`, all three start files, and the `/lib/ld-linux-aarch64.so.1` dynamic loader.

## Completed minimal rootfs — 2026-11-02

[GitHub Actions run 41416484205](https://github.com/forcontact655-collab/arm64-lfs/actions/runs/41416484205) built LFS chapters 6–7 and verified the temporary system in an isolated chroot:

- A newly compiled AArch64 executable ran successfully and printed `LFS_MINIMAL_EXEC_OK`.
- ELF machine and `/lib/ld-linux-aarch64.so.1` interpreter were verified.
- Bash 5.3, GCC 15.2, coreutils 9.7, Python 3.13.7, and Perl 5.42.0 are present.
- `/tools` and `lib64` are absent after the official cleanup.

The `lfs-minimal-rootfs-arm64` artifact and GitHub Actions cache were saved. The rootfs archive is 513,156,920 bytes with SHA-256 `acde9ca99aa0f0714c700c71d3101f84c77e9830e80bd6c3c313a724a8cd03c1`.

This is a minimal chroot/proot system, **not** a bootable LFS and not KDE. The next checkpoint is a separate Termux/proot launch test without modifying the existing Arch installation.
