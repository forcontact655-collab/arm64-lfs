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

This is a minimal chroot/proot system, **not** a bootable LFS and not KDE.

## Completed Termux/proot launch test — 2026-11-02

The verified artifact was downloaded to an isolated directory on the owner-controlled AArch64 Termux device. The archive SHA-256 matched before extraction. Android rejected hard-link creation, so a local Python resume stage copied all 1,064 hard-link entries as independent files without redownloading the archive.

With the Termux `LD_PRELOAD` compatibility hook unset for the raw `proot` process, the launch test compiled and ran a new AArch64 executable inside the LFS rootfs. It printed `TERMUX_PROOT_EXEC_OK` and used `/lib/ld-linux-aarch64.so.1`. Bash 5.3, GCC 15.2, and Python 3.13.7 passed the smoke checks.

The existing Arch installation was not modified. The downloaded archive was removed after success; the isolated LFS rootfs remains available for the next stage. KDE has not been built or started.

## Verified KDE Frameworks and Plasma sources — 2026-11-02

[GitHub Actions run 41424336962](https://github.com/forcontact655-collab/arm64-lfs/actions/runs/41424336962) downloaded and MD5-verified the active BLFS 12.4 package lists for KDE Frameworks 6.17.0 and Plasma 6.4.4. It saved 70 KF6 archives (111,180,268 bytes) and 56 Plasma archives (297,975,140 bytes) in a source cache and generated SHA-256 manifests for later checkpoints.

This is only a source checkpoint. KDE dependencies, Qt, Frameworks, and Plasma have not been compiled yet. The CircleCI configuration now starts by restoring and smoke-testing the existing LFS rootfs rather than rebuilding it.
