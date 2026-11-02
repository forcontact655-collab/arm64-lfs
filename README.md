# ARM64 Linux From Scratch

Experimental, staged **native AArch64 LFS/BLFS 12.4** build. Earlier source, toolchain, rootfs, and KDE-source checkpoints used public GitHub Actions ARM64 runners; the current incremental build stages run on CircleCI ARM64.

The current verified checkpoint adds xfce4-dev-tools 4.20.0, libwnck 43.2, Garcon 4.20.0, Exo 4.20.0, libxfce4ui 4.20.2, startup-notification 0.12, GTK 3.24.50, libjpeg-turbo 3.0.1, GDK-Pixbuf 2.42.12, DejaVu fonts 2.37, Pango 1.56.4, gsettings-desktop-schemas 48.0, at-spi2-core 2.56.4, FriBidi 1.0.16, pixman 0.46.4, Cairo 1.18.4, libepoxy 1.5.10, libxfce4util 4.20.1, and Xfconf 4.20.0, plus the earlier Qt/KDE dependency checkpoints, to Mesa1, graphics1, display2, display1, core1, and the completed LFS chapter-8 rootfs. This repository does **not** yet contain a complete bootable LFS, full XFCE, full Qt, full KDE Frameworks, or Plasma build.

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

This is only a source checkpoint. KDE dependencies, Qt, Frameworks, and Plasma have not been compiled yet. Later CircleCI stages restore verified rootfs caches rather than rebuilding earlier stages.

## Completed LFS chapter 8 — 2026-11-02

CircleCI pipelines **#3** and **#4** completed the two chapter-8 checkpoints: **27** final-toolchain packages and **52** remaining base-system packages, for **79 packages** total. Newly compiled programs executed natively as AArch64. GRUB installation was deliberately skipped, so the result is still **not bootable** and contains no KDE.

## Completed BLFS core1 — 2026-11-02

CircleCI pipeline **#11**, at commit `3ba10da43df36b9e83e1e3d2d7eeffec056a9ad8`, completed the first BLFS checkpoint on top of chapter 8:

- **18 build stages** from **19 MD5-verified source archives**.
- Certificate trust generated by make-ca, with the real `/etc/pki/tls/certs/ca-bundle.crt` bundle checked.
- cURL 8.15.0 includes OpenSSL, libidn2, and libpsl support.
- CMake 4.1.0, D-Bus 1.16.2, GLib 2.84.4, GObject Introspection, docutils, shared-mime-info, desktop-file-utils, Wget, and their stage dependencies are installed.
- A fresh native executable printed `BLFS_CORE1_EXEC_OK` and used `/lib/ld-linux-aarch64.so.1`.

The verified rootfs is saved as the `blfs-12.4-core1-aarch64-v1` CircleCI cache checkpoint. Qt and KDE remain absent.

## Completed BLFS display1 — 2026-11-02

CircleCI pipeline **#12**, at commit `e7eb269b5b6b55a3ec0fe99eb8059bf2db24330d`, restored core1 and completed **16 build stages** from **15 MD5-verified archives**. It installed the libpng/Brotli/Graphite2/ICU/FreeType/HarfBuzz/Fontconfig stack, XCB and its protocol libraries, Wayland 1.24.0, and Wayland Protocols 1.45. FreeType was intentionally rebuilt after HarfBuzz to resolve their circular dependency. A fresh AArch64 smoke executable printed `BLFS_DISPLAY1_EXEC_OK`.

The verified rootfs is saved as the `blfs-12.4-display1-aarch64-v1` CircleCI cache checkpoint. Qt and KDE remain absent.

## Completed BLFS display2 — 2026-11-02

CircleCI pipeline **#13**, at commit `b6d88516900c0880e2abfaaec3e5153315c1cead`, restored display1 and completed **34 build stages** from **34 MD5-verified archives**: the official ordered set of 32 Xorg Libraries, xkeyboard-config 2.45, and libxkbcommon 1.11.0 with X11 and Wayland support. A native AArch64 executable initialized Xlib and compiled a real keymap from the installed xkeyboard data, printing `BLFS_DISPLAY2_EXEC_OK`.

The verified rootfs is saved as the `blfs-12.4-display2-aarch64-v1` CircleCI cache checkpoint. Mesa, Qt, and KDE remain absent.

## Completed BLFS graphics1 — 2026-11-02

CircleCI pipeline **#16**, at commit `d351a947490615d0b2abf1f9b9963e12823d07f8`, completed **6 packages** from **8 MD5-verified sources**: libyaml, Cython, PyYAML with libyaml acceleration, Mako, libdrm 2.4.125, and host-only LLVM 20.1.8. Clang, non-host backends, tests, examples, documentation, and unrelated LLVM tools were deliberately omitted so the stage fits the one-hour job limit.

## Completed BLFS Mesa1 — 2026-11-02

CircleCI pipeline **#19**, at commit `6434abf624dabe70bc14170a5f8530f1e86550e4`, restored graphics1 and built Mesa **25.1.8** with `gallium-drivers=llvmpipe` and OpenCL/Vulkan disabled. The verified artifact report records three DRI entries and a native AArch64 EGL/OpenGL smoke test returning `llvmpipe (LLVM 20.1.8, 128 bits)`. The rootfs is saved as the `blfs-12.4-mesa1-aarch64-v1` CircleCI cache checkpoint. Qt and KDE remain absent; the system is not bootable.

## Completed BLFS qtdeps1 — 2026-11-02

CircleCI pipeline **#20**, at commit `a4176c6bb7f490a96a36b2babd7129044baf4748`, restored Mesa1 and built seven packages: xcb-util, the five official XCB Utilities packages, and double-conversion 3.3.1. All nine double-conversion tests passed, and a native AArch64 executable loaded every new shared library. ICU 77.1 from display1 was reused rather than rebuilt. The rootfs is saved as the `blfs-12.4-qtdeps1-aarch64-v1` CircleCI cache checkpoint; Qt and KDE remain absent.

## Completed BLFS qtbase1 — 2026-11-02

CircleCI pipeline **#26**, at commit `ebb1e95c4e4f80168e3013525da57697cc695108`, restored qtdeps1 and built the official QtBase **6.9.2** submodule archive rather than the full 47 GB Qt source build. Five authenticated artifacts were inspected separately from the green job status. The report verifies a native AArch64 offscreen Qt GUI smoke test, the XCB and offscreen platform plugins, bundled SQLite, and the `/lib/ld-linux-aarch64.so.1` interpreter.

The verified rootfs is saved as the `blfs-12.4-qtbase1-aarch64-v1` CircleCI cache checkpoint. Further Qt modules, Frameworks, and Plasma remain later stages; the system is not bootable and no KDE is installed.

## Completed BLFS qtquickdeps1 — 2026-11-02

CircleCI pipeline **#27**, at commit `39e8de257a6ee1f096d5a91b2cbba80ffa8ab436`, restored qtbase1 and built the official QtShaderTools and QtSvg **6.9.2** submodule archives. All job steps succeeded, and nine artifacts were downloaded for separate inspection. The report verifies a native `qsb` shader bake, a compiled offscreen QtSvg render test, both SVG plugins, and the AArch64 dynamic linker.

The verified rootfs is saved as the `blfs-12.4-qtquickdeps1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun.

## Completed BLFS qtdeclarative1 — 2026-11-02

CircleCI pipeline **#28**, at commit `16a1b3221babf8318ec6d94c5339cea91b204389`, restored qtquickdeps1 and built the official QtDeclarative **6.9.2** archive. All ten job steps succeeded, and eight artifacts were downloaded for separate inspection. The report verifies a compiled native AArch64 smoke test that imports QtQuick and QtQuick.Controls and instantiates a QML control with the offscreen platform.

The verified rootfs is saved as the `blfs-12.4-qtdeclarative1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Further Qt modules, Frameworks, and Plasma remain later stages; no KDE is installed and the system is not bootable.

## Completed BLFS qt5compat1 — 2026-11-02

CircleCI pipeline **#30**, at commit `92c3da83dadcb752d040c331897bd310003082b5`, restored qtdeclarative1 and built the official Qt5Compat **6.9.2** archive. All ten job steps succeeded, and eight artifacts were downloaded for separate inspection. The report verifies a compiled native AArch64 Core5Compat smoke test and the installed Qt5Compat.GraphicalEffects QML module.

The verified rootfs is saved as the `blfs-12.4-qt5compat1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Further Qt modules, Frameworks, and Plasma remain later stages; no KDE is installed and the system is not bootable.

## Completed BLFS kf6-ecm1 — 2026-11-02

CircleCI pipeline **#31**, at commit `d37d1366b3c859378651fd2ee5f114fe55762e5c`, restored qt5compat1 and built Extra CMake Modules **6.17.0** with the required BLFS patch and installation fixes. All ten job steps succeeded, and seven artifacts were downloaded for separate inspection.

A compiled native AArch64 integration smoke test verified ECM discovery, preservation of `PACKAGE_PREFIX_DIR`, `KDE_INSTALL_LIBDIR=lib`, `ECMSetupVersion`, and Qt 6.9.2. The verified rootfs is saved as the `blfs-12.4-kf6-ecm1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Only ECM is installed: KDE Frameworks and Plasma remain absent, and the system is not bootable.

## Completed BLFS qttools1 — 2026-11-02

CircleCI pipeline **#32**, at commit `71804edcc51fbb1c7947ed9feac54a8136867384`, restored kf6-ecm1 and built the Linguist tools from the official QtTools **6.9.2** archive. All ten job steps succeeded, and eight artifacts were downloaded for separate inspection. QDoc, Designer, Assistant, and unrelated tools were disabled; this is not a full QtTools build and does not include Clang-based lupdate parsing.

Acceptance verified `Qt6LinguistTools`, `lrelease`, `lconvert`, and `lupdate`; a TS/QM/TS round trip; and a compiled native AArch64 `QTranslator` smoke test using the generated Russian catalog. The verified rootfs is saved as the `blfs-12.4-qttools1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Only ECM is installed from KDE; Frameworks and Plasma remain absent, and the system is not bootable.

## Completed BLFS kf6-attica1 — 2026-11-02

CircleCI pipeline **#33**, at commit `b284363397942f53a6ec2df5594b5431ddf69b4c`, restored qttools1, initialized `/opt/kf6` and its profile/linker configuration, and built Attica **6.17.0**. All ten job steps succeeded, and seven artifacts were downloaded for separate inspection. Acceptance used an offline compiled native AArch64 `Attica::Category` smoke test; no Open Collaboration Services provider was contacted.

The verified rootfs is saved as the `blfs-12.4-kf6-attica1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Only Attica is installed from KF6; the remaining Frameworks and Plasma are absent. The owner then directed an XFCE-first route for a faster initial desktop, so further KF6 stages are paused at this verified checkpoint. The system is not bootable.

## Completed BLFS xfce-libxfce4util1 — 2026-11-02

CircleCI pipeline **#35**, at commit `1e4ebdf9eadec109d3db47ace54b43296413e7e3`, restored the accepted Attica checkpoint and built libxfce4util **4.20.1** with GObject Introspection. All ten job steps succeeded, and seven artifacts were downloaded for separate inspection. Pipeline #34 had failed only because the acceptance script looked for `xfce4-kiosk-query` in `/usr/bin` instead of its actual `/usr/sbin` location; the corrected stage was then verified end to end.

Acceptance checked the GIR/typelib installation and ran a compiled native AArch64 smoke test through `libxfce4util-1.0`. The verified rootfs is saved as the `blfs-12.4-xfce-libxfce4util1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Only this XFCE utility library is installed; a full XFCE desktop and a bootable system are not claimed.

## Completed BLFS xfce-xfconf1 — 2026-11-02

CircleCI pipeline **#36**, at commit `bb1dff51de569067f85541ec60f1e73032984032`, restored libxfce4util1 and built Xfconf **4.20.0** with GObject Introspection. All ten job steps succeeded, and seven artifacts were downloaded for separate inspection. Acceptance checked `xfconf-query`, `xfconfd`, D-Bus activation and the GIR/typelib files, then created and read back an integer property through a private `dbus-run-session`; temporary configuration was removed.

The verified rootfs is saved as the `blfs-12.4-xfce-xfconf1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. libxfce4util and Xfconf are installed, but a full XFCE desktop and a bootable system are not claimed.

## Completed BLFS xfce-gtkdeps1 — 2026-11-02

CircleCI pipeline **#38**, at commit `359f6673adaa24afbc0a93b05895597c4eeabd13`, restored the accepted Xfconf checkpoint and built FriBidi **1.0.16**, pixman **0.46.4**, Cairo **1.18.4**, and libepoxy **1.5.10**. Pipeline #37 had stopped before Cairo compilation because Meson defaulted to `lib64`; the corrected stage explicitly uses `--libdir=lib`. All ten job steps succeeded, and twelve artifacts were downloaded for separate inspection.

Acceptance verified **8 passed / 0 failed** FriBidi tests, **35 / 0** pixman tests, and **4 / 0** libepoxy tests with **13 display-dependent skips**. A compiled native AArch64 smoke executable exercised all four libraries and wrote a verified 32×32 Cairo PNG. The source SHA-256 manifest matched the independently downloaded sources. The verified rootfs is saved as the `blfs-12.4-xfce-gtkdeps1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. GTK3, Pango, GDK-Pixbuf, at-spi2-core, and libxfce4ui remain separate later stages; the system is not bootable.

## Completed BLFS xfce-gtkdeps2 — 2026-11-02

CircleCI pipeline **#40**, at commit `9a47524c1a11196eca67a29eea34f0fbc1519de6`, restored gtkdeps1 and built libjpeg-turbo **3.0.1**, GDK-Pixbuf **2.42.12**, DejaVu fonts **2.37**, Pango **1.56.4**, gsettings-desktop-schemas **48.0**, and at-spi2-core **2.56.4**. Pipeline #39 had exposed missing usable fonts through five additional Pango failures; the corrected stage installs 22 DejaVu TTFs and verifies Fontconfig before Pango. All ten job steps succeeded, and thirteen artifacts were downloaded for separate inspection.

Acceptance verified **295/295** libjpeg-turbo tests, **23/23** GDK-Pixbuf tests, and **23/23** Pango tests with only the three font-data exclusions documented by BLFS. A compiled native AArch64 smoke test exercised JPEG/PNG loading, a Pango layout with nonzero text extents, Cairo PNG output, AT-SPI versioning, and the installed GSettings schema. The AT-SPI graphical test suite is not claimed. The verified rootfs is saved as the `blfs-12.4-xfce-gtkdeps2-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-gtk3 — 2026-11-02

CircleCI pipeline **#41**, at commit `f4da3a3d045bbd9b0348cdd5da64635446513be8`, restored gtkdeps2 and built GTK **3.24.50** with X11, Wayland, Broadway, and GObject Introspection support. All ten job steps succeeded, and nine artifacts were downloaded for separate inspection. Acceptance verified the official source SHA-256, installed GIR/typelib files, all three GDK backends, and a compiled native AArch64 GTK window/label smoke test through a private Broadway display. The full graphical GTK test suite was not run and is not claimed.

The verified rootfs is saved as the `blfs-12.4-xfce-gtk3-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. GTK3 is now installed; libxfce4ui and the remaining XFCE packages are still separate stages, and the system is not bootable.

## Completed BLFS xfce-libxfce4ui1 — 2026-11-02

CircleCI pipeline **#43**, at commit `b057e8fc1fcfddff88da5ac455f60546dfcc148f`, restored GTK3 and built startup-notification **0.12** followed by libxfce4ui **4.20.2**. Pipeline #42 had stopped before compilation because startup-notification's 2011 `config.guess` did not recognize AArch64; the corrected stage passes an explicit native build triplet. All ten job steps succeeded, and seven artifacts were downloaded for separate inspection.

Acceptance verified both package versions, the keyboard library, GObject Introspection, startup-notification linkage, and a compiled native AArch64 libxfce4ui smoke test. Neither package provides a test suite. The verified rootfs is saved as the `blfs-12.4-xfce-libxfce4ui1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-exo1 — 2026-11-02

CircleCI pipeline **#44**, at commit `809558ad478d235244997ccaba1bf99caea22df8`, restored libxfce4ui1 and built Exo **4.20.0**. All ten job steps succeeded, and nine artifacts were downloaded for separate inspection. Acceptance verified the official source checksum, **2/2** upstream tests, the ABI check, and a compiled native AArch64 Exo library smoke test.

The verified rootfs is saved as the `blfs-12.4-xfce-exo1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Exo is installed; Garcon and the remaining XFCE packages are still separate stages, and the system is not bootable.

## Completed BLFS xfce-garcon1 — 2026-11-02

CircleCI pipeline **#46**, at commit `a4ec9925c6aa241a00d9483a11efcc39c109f842`, restored Exo and built Garcon **4.20.0**, including its core and GTK3 libraries plus GObject Introspection. Pipeline #45 completed the package but failed the additional native smoke because Garcon 4.20.0 declares `garcon_menu_item_action_new` without exporting an implementation; the corrected smoke instantiates the same GObject type directly and tests its exported setter/getter functions. All ten job steps succeeded, and eight artifacts were downloaded for separate inspection.

Acceptance verified both libraries and GIR/typelib pairs plus the compiled native AArch64 smoke test. BLFS provides no Garcon test suite. The verified rootfs is saved as the `blfs-12.4-xfce-garcon1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-libwnck1 — 2026-11-02

CircleCI pipeline **#48**, at commit `ed8cabf29b5872f25360f1d6401ee1c39eebe144`, restored Garcon and built libwnck **43.2** with X11 tools, startup-notification, and GObject Introspection. Pipeline #47 completed the package but stopped at the additional native smoke because libwnck requires consumers to acknowledge its unstable API; the corrected smoke defines `WNCK_I_KNOW_THIS_IS_UNSTABLE`. All ten job steps succeeded, and eight artifacts were downloaded for separate inspection.

Acceptance verified the installed tools, Wnck GIR/typelib, startup-notification linkage, and a compiled native AArch64 type/version smoke test. BLFS provides no libwnck test suite, and no live window-manager session is claimed. The verified rootfs is saved as the `blfs-12.4-xfce-libwnck1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-devtools1 — 2026-11-02

CircleCI pipeline **#49**, at commit `6626b56b546156b92cb318d80a35f873581262a7`, restored libwnck1 and built xfce4-dev-tools **4.20.0**. All ten job steps succeeded, and eight artifacts were downloaded for separate inspection.

Acceptance verified the upstream `test-xdt-csource` result (**1/1 passed, 0 failed, 0 errors**), `xdt-autogen`, the installed m4 macros, and native AArch64 execution of `xdt-csource 4.20.0`. The verified rootfs is saved as the `blfs-12.4-xfce-devtools1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Active BLFS xfce-libxfce4windowing1 stage

The next unverified stage restores devtools1 and builds the required **hwdata 0.398 → libdisplay-info 0.3.0 → libxfce4windowing 4.20.4** chain. It runs libdisplay-info's upstream `ninja test` suite and enables X11 plus GObject Introspection for libxfce4windowing. Acceptance requires every job step and artifact, both windowing libraries and their GIR/typelibs, the X11 pkg-config module, and a native AArch64 smoke that parses the upstream QEMU EDID fixture through libdisplay-info and exercises the windowing/UI types without claiming a live desktop session.
