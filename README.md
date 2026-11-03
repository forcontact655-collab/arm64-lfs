# ARM64 Linux From Scratch

Experimental, staged **native AArch64 LFS/BLFS 12.4** build. Earlier source, toolchain, rootfs, and KDE-source checkpoints used public GitHub Actions ARM64 runners; the current incremental build stages run on CircleCI ARM64.

The current verified checkpoint is `blfs-12.4-xfce-launch1-aarch64-v1`: the completed LFS chapter-8 rootfs, the earlier Qt/KDE dependency checkpoints, **XFCE core 18/18**, and the launch additions libxcvt 0.1.3, font-util 1.4.1, xkbcomp 1.4.7, Xorg Server 21.1.18, and xrdb 1.2.2. A native AArch64 Xvfb/`startxfce4` launch is verified through live session processes, X11 properties, and a nonblank screenshot. This repository does **not** yet contain a complete bootable LFS, the full XFCE application set, full Qt, full KDE Frameworks, or Plasma. `BOOTABLE=no` remains explicit.

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

## Completed BLFS xfce-libxfce4windowing1 — 2026-11-02

CircleCI pipeline **#50**, at commit `49a1fc54cd4d26f18292c69f505f90bd4461a2b5`, restored devtools1 and built **hwdata 0.398 → libdisplay-info 0.3.0 → libxfce4windowing 4.20.4**. All ten job steps succeeded, and ten artifacts were downloaded for separate inspection.

Acceptance verified libdisplay-info's upstream suite (**64 passed, 0 failed**), both windowing libraries and their GIR/typelibs, the X11 pkg-config module, and a native AArch64 smoke that parsed the upstream QEMU EDID fixture as EDID 1.4 with Red Hat/QEMU identity and exercised the windowing/UI types. The verified rootfs is saved as the `blfs-12.4-xfce-libxfce4windowing1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; no live desktop session or bootability is claimed.

## Completed BLFS xfce-xfce4-panel1 — 2026-11-02

CircleCI pipeline **#51**, at commit `5962f0d09f99bd238aa56d54a1a976d63033170b`, restored libxfce4windowing1 and built xfce4-panel **4.20.5** with X11 and GObject Introspection. All ten job steps succeeded, and eight artifacts were downloaded for separate inspection.

Acceptance verified the panel programs and plugins, `libxfce4panel-2.0`, its GIR/typelib, and a native AArch64 type/version smoke. BLFS provides no test suite, and no graphical panel session is claimed. The verified rootfs is saved as the `blfs-12.4-xfce-xfce4-panel1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-thunar1 — 2026-11-02

CircleCI pipeline **#52**, at commit `a257e6ef4ac0bc2411c606e736f9420b9096c858`, restored xfce4-panel1 and built **hicolor-icon-theme 0.18 → libgudev 238 → libnotify 0.8.6 → Thunar 4.20.4**. All ten job steps succeeded, and eight artifacts were downloaded for separate inspection.

Acceptance verified all three libraries and their GIR/typelibs, the Thunar and notification programs, and a native AArch64 smoke covering GUdev types, libnotify init/uninit without a daemon, and Thunarx version/types. Umockdev and interactive notification tests were explicitly not claimed. The verified rootfs is saved as the `blfs-12.4-xfce-thunar1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; no file-manager GUI, notification-daemon session, or bootability is claimed.

## Completed BLFS xfce-thunar-volman1 — 2026-11-02

CircleCI pipeline **#53**, at commit `945c550a8636d52bb4198877ffa241249c0ba947`, restored Thunar1 and built thunar-volman **4.20.0** with libnotify support. All ten job steps succeeded, and seven artifacts were downloaded for separate inspection.

Acceptance verified both installed programs, their AArch64 loaders, and execution of `thunar-volman --version` through GTK's headless Broadway backend. This was only a native version smoke, not a device-management test or a live graphical session; optional GVfs runtime support is not claimed. The verified rootfs is saved as the `blfs-12.4-xfce-thunar-volman1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-tumbler1 — 2026-11-02

CircleCI pipeline **#55**, at commit `41f24f03dcbe2cc1a1352da05ca528bf95ba58d3`, restored thunar-volman1 and built Tumbler **4.20.0**, then removed its SysV-inapplicable systemd user unit as directed by BLFS. Pipeline #54 built and installed the package but stopped while compiling the additional smoke because the public Tumbler header includes GDK-Pixbuf without propagating its include flags through `tumbler-1.pc`; the corrected smoke explicitly adds `gdk-pixbuf-2.0`.

All ten job steps in #55 succeeded, and eight artifacts were downloaded for separate inspection. Acceptance verified `tumblerd`, `libtumbler-1`, thumbnailer plugins, D-Bus service files, and a native AArch64 type/version smoke. No D-Bus session or actual thumbnail generation is claimed. The verified rootfs is saved as the `blfs-12.4-xfce-tumbler1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-xfce4-appfinder1 — 2026-11-02

CircleCI pipeline **#56**, at commit `dc9e805144a6cce86349de1f14293969cfb0ee5d`, restored Tumbler1 and built xfce4-appfinder **4.20.0**. BLFS provides no test suite. All ten job steps succeeded, and seven artifacts were downloaded for separate inspection. Acceptance verified `xfce4-appfinder`, the `xfrun4` symlink, their AArch64 loaders, and execution of `xfce4-appfinder --version` through GTK's headless Broadway backend. No application-search test or live graphical session is claimed. The verified rootfs is saved as the `blfs-12.4-xfce-xfce4-appfinder1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-power-deps1 — 2026-11-02

CircleCI pipeline **#59**, at commit `28137dd3faceed9851c5b7ce992ec9921ee4784b`, restored xfce4-appfinder1 and built the required xfce4-power-manager dependencies libusb **1.0.29** and UPower **1.90.9**. Libusb has no test suite. Pipeline #57 built both packages and passed the UPower self-test 1/1, but stopped when artifact collection looked for `testlog.jsonl` while this Meson version writes `testlog.txt`. Pipeline #58 then passed the build, self-test, and native smoke but its post-check incorrectly expected Meson's console summary inside the detailed log.

All ten job steps in #59 succeeded, and nine artifacts were downloaded for separate inspection. The detailed UPower self-test log contains seven passing TAP cases, with two internal D-Bus cases explicitly skipped; integration tests are not claimed because optional dbusmock/umockdev/session dependencies are absent. Acceptance also verified installed programs/libraries and native libusb/UPower type smoke plus `upower --help`. No USB hardware access, UPower daemon, D-Bus service, or power-device operation is claimed. The verified rootfs is saved as the `blfs-12.4-xfce-power-deps1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-polkit1 — 2026-11-02

CircleCI pipeline **#65**, at commit `2061750ba64e43c44da4ea870ea8c9427114c5e9`, restored power-deps1 and built duktape **2.7.0**, elogind **255.17**, and Polkit **126** with elogind session tracking and Shadow authentication. Linux-PAM remains a deferred recommended dependency. All ten job steps succeeded, and ten artifacts were downloaded for separate inspection.

Independent acceptance recounted **181 OK / 1 FAIL / 5 SKIP** in elogind: the only failure is BLFS-known `check-version-history`, with zero unexpected failures. All four Polkit unit executables passed **29 TAP checks**; the JavaScript-authority test requiring dbusmock is not claimed. Acceptance also verified official source checksums, installed programs/libraries, actual `/usr/libexec/elogind`, upstream project version **255** versus release **255.17**, native duktape evaluation and Polkit user API, and CLI version tools. Failed pipelines #60–#64 exposed and corrected mount/test isolation, loader-cache, version-format, install-path, and smoke-API issues; none is accepted or rerun. No daemon, D-Bus session, login session, or authorization operation is started. The verified rootfs is saved as the `blfs-12.4-xfce-polkit1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-xfce4-power-manager1 — 2026-11-02

CircleCI pipeline **#66**, at commit `71e073ecc6c646c1aca959c4887f60ab6a41bf10`, restored Polkit1 and built xfce4-power-manager **4.20.0** from the official archive. All ten job steps succeeded, and seven artifacts were downloaded for separate inspection. BLFS provides no test suite.

Acceptance verified all four installed programs, explicitly including the Polkit-conditional `xfce4-pm-helper` and `xfpm-power-backlight-helper`, plus the panel plugin, Polkit policy, AArch64 loaders, official source checksum, and native `Xfce Power Manager 4.20.0` version execution. No daemon, GUI settings session, D-Bus session, device access, suspend, hibernate, or backlight operation is claimed. The verified rootfs is saved as the `blfs-12.4-xfce-xfce4-power-manager1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun; the system is not bootable.

## Completed BLFS xfce-usb-test-deps1 — 2026-11-03

CircleCI pipeline **#70**, at commit `34dfc1f2c57a9924c1e9f3c81e59cc651418a5aa`, restored xfce4-power-manager1 and built libpcap **1.10.5**, Vala **0.56.18**, and umockdev **0.19.3** from official sources. All ten job steps succeeded, and eleven artifacts were downloaded for separate inspection. Libpcap has no test suite; Vala's `make check` and all six selected umockdev C/Vala/static suites passed. The Python GI test was not run because PyGObject is absent, and the upstream X11 integration test self-skipped because Xorg is absent.

Acceptance verified the libraries, UMockdev GIR/typelib and VAPI, actual compiled programs versus the `vala-gen-introspect` shell launcher, and native AArch64 C plus Vala smoke executables. The verified rootfs is saved as the `blfs-12.4-xfce-usb-test-deps1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Pipelines #67, #68, and #69 remain failed and unaccepted; none will be rerun.

## Completed BLFS xfce-color-deps1 — 2026-11-03

CircleCI pipeline **#74**, at commit `87c2e33617538e01107e9be66d52b7003ebe6d7b`, restored the accepted usb-test-deps1 checkpoint and built SQLite **3.50.4**, lcms2 **2.17**, JSON-GLib **1.10.6**, libgusb **0.4.9**, and colord **1.4.8**. All ten job steps succeeded; fourteen artifacts were downloaded and independently inspected. The verified rootfs is saved as the `blfs-12.4-xfce-color-deps1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun.

Acceptance verified the native SQLite `3.50.4|4` query because upstream provides no test suite, the lcms2 `make check` testcms run, JSON-GLib **17/17**, both selected libgusb Meson tests, all seven wrapped `gusb-self-test` subtests with the virtual Canon `04a9:31c0`, and four colord suites with three passes plus the expected `colord-test-daemon` skip. The udev hwdb was generated and used for the EDID vendor tests. GUsb/Colord VAPIs and the native four-library AArch64 smoke were also verified. Optional libtiff and Bash Completion remain absent/disabled; no real USB device, color daemon, or color-management operation is claimed. Pipelines #71, #72, and #73 remain failed and unaccepted and will not be rerun.

## Completed BLFS xfce-xfce4-settings1 — 2026-11-03

CircleCI pipeline **#75**, at commit `7584173b7665cab87cedf9be6d6caf15d3b31f80`, restored accepted color-deps1 and built LXDE Icon Theme **0.5.1** plus xfce4-settings **4.20.2**. All ten job steps succeeded; eight artifacts were independently inspected. Acceptance verified all twelve settings programs, `HAVE_COLORD=1` in the saved `config.h`, the libcolord link, the nuoveXT2 icon cache, and native Broadway version execution of both `xfce4-settings-manager` and `xfce4-color-settings`.

The verified rootfs is saved as the `blfs-12.4-xfce-xfce4-settings1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. XFCE core is now **15/18**; no settings GUI, xfsettingsd, D-Bus session, or color/display operation is claimed. Pipeline #67 remains failed and unaccepted and will not be rerun.

## Completed BLFS xfce-core-final1 — 2026-11-03

CircleCI pipeline **#77**, at commit `69f371fbdc1d8225e53b44e01801f66d23b7e877`, restored accepted settings1 and built official Xorg iceauth **1.0.10**, Xfdesktop **4.20.1**, Xfwm4 **4.20.0**, and xfce4-session **4.20.3**. All ten job steps succeeded; eight artifacts were independently inspected. Acceptance verified iceauth, all nine XFCE ELF programs, the `startxfce4` and `xflock4` scripts, desktop/MIME database updates, and four native version checks including three safe Broadway paths.

The verified rootfs is saved as the `blfs-12.4-xfce-core-final1-aarch64-v1` CircleCI cache checkpoint. **XFCE core is 18/18.** Pipeline #77 is accepted and must not be rerun. Pipeline #76 failed only because xfce4-session could not find iceauth; it was not accepted and was not rerun. Core completion did not itself test a desktop launch and did not make the rootfs bootable.

## Completed BLFS xfce-launch1 — 2026-11-03

CircleCI pipeline **#83**, at commit `1b191a990670e41aac99ce5af2a2bf2c4942954c`, restored accepted core-final1 and built libxcvt **0.1.3**, font-util **1.4.1**, xkbcomp **1.4.7**, Xorg Server **21.1.18**, and xrdb **1.2.2**. All ten job steps succeeded; fourteen artifacts were downloaded and independently inspected. The verified rootfs is saved as the `blfs-12.4-xfce-launch1-aarch64-v1` CircleCI cache checkpoint. **Pipeline #83 is accepted and must not be rerun.**

Acceptance required the exact Xorg result **5 OK / 1 expected XTS SKIP / 0 Fail**, native utility execution, the correct font-util map path, and live server vendor release **12101018**. Xvfb allocated display `:0` through `-displayfd`; `startxfce4` then launched xfce4-session, Xfwm4, Xfdesktop, xfce4-panel, and xfsettingsd. The X11 probe found `WM_NAME=xfwm4` and three clients. The 1280x800 RGB PNG screenshot was visually inspected and contains the XFCE Applications menu, panel, desktop icons, and launcher; it has 989,017 non-background pixels and 64 sampled colors. The session was stopped and its temporary configuration removed after validation.

Pipelines **#78–#82** remain failed, unaccepted, and must not be rerun. Their respective failures were the wrong libepoxy pkg-config module, an incorrect existing-library absence precondition, the wrong font-map post-check path, a fixed-display conflict with CircleCI's host Xvfb, and an incorrect assumption that Xvfb would emit a version banner. Pipeline #82 did produce a live desktop, but only #83 passed every build, launch, artifact, and independent acceptance check.

This is a headless launch test only. Real displays, hardware acceleration, rootless Xorg, installation on a phone, and bootability remain untested; `BOOTABLE=no` stays explicit. KDE has resumed from the accepted Attica checkpoint; see the verified KF6 base1 stage below. Plasma remains absent.

## Active XFCE Termux export — 2026-11-03

The owner authorized preparing the verified XFCE system for Termux beside the existing Arch installation. This export-only stage restores the accepted launch1 cache from pipeline **#83** and does not rebuild XFCE or repeat its desktop-launch pipeline. It creates a SHA-256-verified rootfs archive, dereferences hardlinks for Android filesystem compatibility, excludes build-only tools/sources and virtual runtime contents, and independently rechecks the archive. The existing Arch system is not accessed or modified. This is a migration checkpoint, not the final customized and fully equipped desktop. Packaging in CI is not phone installation; `BOOTABLE=no` remains unchanged.

## Completed BLFS kf6-base1 — 2026-11-03

CircleCI pipeline **#88**, at commit `24ab10f8c51e36ea695cb157cc571f3ba7935002`, restored the accepted apps1 cache and built KF6 **karchive, kcodecs, kconfig, kcoreaddons, and kdbusaddons 6.17.0** without rerunning Attica or XFCE. The workflow and job succeeded, and seven artifacts were downloaded for independent acceptance. Source SHA-256 values and the five-package build order matched the official KF6 manifest.

A compiled native AArch64 smoke executable verified KAboutData, a KConfig write/read round trip, and KCharsets; KArchive and KDBusAddons were discovered and linked. Package test suites were not run because the BLFS build uses `BUILD_TESTING=OFF`. Kapidox remains a deferred documentation tool. The verified rootfs is saved as the `blfs-12.4-kf6-base1-aarch64-v1` CircleCI cache checkpoint. This stage is accepted and must not be rerun. Plasma remains absent and `BOOTABLE=no` is unchanged.

## Completed BLFS kf6-base2 — 2026-11-03

CircleCI pipeline **#91**, at commit `0bcfa09988ef64e2aff459d2acb11e9a455053b3`, restored the accepted base1 cache and added **qtwayland 6.9.2** plus **plasma-wayland-protocols 1.18.0** before building KF6 **kguiaddons, ki18n, and kidletime 6.17.0**. The workflow and job succeeded; all seven artifacts, five source SHA-256 rows, dependency order, and package order were independently verified.

The native AArch64 smoke executable verified KLocalizedString and Qt6WaylandClient, with GuiAddons and IdleTime found and linked. Package test suites were not run (`BUILD_TESTING=OFF`), and no Wayland-compositor runtime test was performed. Pipelines **#89** and **#90** remain failed dependency-discovery attempts and must not be rerun. Base2 is accepted through its dedicated CircleCI cache checkpoint; Attica, base1, and XFCE were preserved. KDNSSD remains deferred for its Avahi/DNS-SD backend, KImageFormats for dedicated Qt-plugin validation, Plasma is absent, and `BOOTABLE=no` is unchanged.

Pipeline **#92** was a redundant Qt Declarative attempt. Its absence precondition stopped the job before compilation because the accepted qtdeclarative1 pipeline **#28** already provided QML and QtQuick. It did not save a rootfs cache and must not be rerun; the superseded duplicate stage files were removed when base3 was prepared.

## Completed BLFS kf6-base3 — 2026-11-03

CircleCI pipeline **#94**, at commit `bb77f74dd4bcd46509745baeb493ac9daba699a7`, restored the accepted base2 cache and built KF6 **kitemmodels, kitemviews, kplotting, kwidgetsaddons, and kwindowsystem 6.17.0**. QML support uses the previously accepted QtDeclarative pipeline **#28**; no duplicate Qt build was performed. All five source hashes and seven artifacts were independently verified.

The compiled native AArch64 smoke created a QQuickItem while importing `org.kde.kitemmodels` and `org.kde.kwindowsystem`; it also linked all five libraries and instantiated KDescendantsProxyModel and KPlotWidget. Three designer plugins were built but not run. X11 and Wayland support was compiled in, but no real-display runtime test was performed. Package test suites were not run (`BUILD_TESTING=OFF`). Pipeline **#93** had built the packages but failed its incorrect QML installation-path post-check; it was not rerun and did not save a rootfs cache. Base3 is accepted through its dedicated CircleCI cache checkpoint. KDNSSD and KImageFormats remain deferred, Plasma is absent, and `BOOTABLE=no` is unchanged.

## Completed BLFS kf6-base4 — 2026-11-03

CircleCI pipeline **#96**, at commit `d50dcf85b4e065b62c890666626382e6d6ee6094`, restored the accepted base3 cache and built KF6 **solid, sonnet, and threadweaver 6.17.0**, with **Aspell 0.60.8.1** and its English dictionary as new dependencies. All five source hashes and seven artifacts were independently verified. NetworkManager-Qt remains deferred for a NetworkManager backend.

The native AArch64 smoke verified an empty Solid device without probing hardware, used Sonnet/Aspell to accept `hello` and reject `zzzzqqqq`, executed and finished one ThreadWeaver job, and imported `org.kde.sonnet` offscreen. UDisks and hardware runtimes were not tested. Aspell provides no upstream test suite; KF6 package tests were not run (`BUILD_TESTING=OFF`). Pipeline **#95** built the libraries but failed compiling the smoke because of a C++ most-vexing-parse typo; it did not save a rootfs cache and was not rerun. Base4 is accepted through its dedicated CircleCI cache checkpoint. Plasma remains absent and `BOOTABLE=no` is unchanged.

## Completed BLFS kf6-base5 — 2026-11-03

CircleCI pipeline **#98**, at commit `f5c2946dc96f7da0ad67a8d9462b833f7699cc24`, restored accepted base4 and built KF6 **kauth, kcompletion, kcrash, kdoctools, kpty, and kunitconversion 6.17.0**, with Polkit-Qt, DocBook XML, docbook-xsl-nons, MIME-Base32, and URI as new dependencies. All 12 source hashes and seven artifacts were independently verified.

The native AArch64 smoke checked KCompletion, a KAuth action object, PTY open/close, and conversion of 1 km to 1000 m; KCrash was linked without triggering crash handling. The system DocBook catalog passed direct `xmllint` validation, and `meinproc6` validated a KDE DocBook document and generated HTML. MIME-Base32's tests passed. URI's full test suite was not run because its recommended test-only dependencies are absent; KF6 tests were disabled as in BLFS. KAuth authorization runtime was not tested.

Pipeline **#97** built the packages but failed the initial DocBook smoke because `meinproc6` replaces `XML_CATALOG_FILES` with KDocTools' own catalogs. It saved no rootfs cache, was not accepted, and was not rerun. Base5 is accepted through the corrected pipeline's dedicated CircleCI cache checkpoint and must not be rerun. Plasma remains absent and `BOOTABLE=no` is unchanged.

## Completed BLFS kf6-base6 — 2026-11-03

CircleCI pipeline **#100**, at commit `9d01dc2e369ffe0236fa2fc46411c211a222ce60`, restored accepted base5 and built KF6 **kcolorscheme, kconfigwidgets, kservice, kglobalaccel, kpackage, and kdesu 6.17.0**. All six source hashes and seven artifacts were independently verified. The native AArch64 smoke passed offscreen color lookup, `KStandardAction`, a KService object, a default shortcut-info object, generic-package data-file lookup, and KDESu PTY execution of `/bin/true`.

No global-shortcut daemon/registration or privilege-elevation runtime was tested. KF6 test suites remained disabled. Pipeline **#99** built all six libraries but failed the first KPackage smoke because the synthetic package placed `data/` outside KPackage's default `contents/` prefix; it saved no rootfs cache, was not accepted, and was not rerun. Base6 is accepted only through corrected pipeline #100 and must not be rerun. Plasma remains absent and `BOOTABLE=no` is unchanged.

## Completed BLFS kf6-audio-deps1 — 2026-11-03

CircleCI pipeline **#102**, at commit `aeb281bb336bf8ecb005dcf75e1f02eb038f9226`, restored accepted base6 and built **libogg 1.3.6, libvorbis 1.3.7, ALSA lib 1.2.14, and libcanberra 0.30**, with ALSA UCM configuration and libcanberra's required Wayland patch. All six source hashes and seven artifacts were independently verified. Libogg, libvorbis, and ALSA test suites passed; libcanberra has no test suite. The native AArch64 smoke exercised Ogg stream setup/cleanup, Vorbis version lookup, ALSA version lookup, and libcanberra context create/destroy.

The libcanberra ALSA backend and GTK3 bindings were built, but no sound playback or hardware access was tested. PulseAudio, GStreamer, udev, and tdb backends were disabled; a sound theme is not installed. Pipeline **#101** built the packages but failed a post-install assertion that looked for UCM configuration at `/usr/share/alsa/ucm.conf` instead of `/usr/share/alsa/ucm2/ucm.conf`; it saved no rootfs cache, was not accepted, and was not rerun. This stage is accepted only through corrected pipeline #102 and must not be rerun. Plasma remains absent and `BOOTABLE=no` is unchanged.

## Completed BLFS kf6-base7 — 2026-11-03

CircleCI pipeline **#106**, at commit `abd422ad782844f7f6cce590f32449f273898e42`, restored the accepted audio-dependency checkpoint and built **Breeze Icons 6.17.0** plus KF6 **kiconthemes, knotifications, kjobwidgets, ktextwidgets, kxmlgui, and kbookmarks 6.17.0**. All seven source hashes and seven artifacts were independently verified. The native AArch64 offscreen smoke passed Breeze icon lookup, notification and job-tracker object construction, text editing, an XML GUI action collection, and DOM bookmark creation.

No notification was sent, no job or audio playback was run, and QtSpeech support was disabled because QtTextToSpeech has not been built. KF6 test suites remained disabled. Pipelines **#103**, **#104**, and **#105** were not accepted and saved no rootfs cache: #103 lacked the Breeze Icons dependency, #104 used a nonexistent `KBookmarkGroup` wrapper header in the smoke, and #105 used `iconPath` without the required filename extension instead of `iconPathByName`. They must not be rerun. Base7 is accepted only through corrected pipeline #106 and must not be rerun. Plasma remains absent and `BOOTABLE=no` is unchanged.

## Completed BLFS kf6-security-deps1 — 2026-11-03

CircleCI pipeline **#109**, at commit `6d6c94a41ce4870d0de1548104211613b63cb66e`, built **libgpg-error 1.55**, **libgcrypt 1.11.2**, and **QCA 2.3.10** against the accepted base7 checkpoint. All three source hashes and seven artifacts were independently verified. The libgpg-error, libgcrypt, and QCA test suites passed; the native AArch64 smoke verified libgcrypt SHA-256 and the explicit QCA **qca-ossl** SHA-256 provider. QCA is installed under `/opt/qt6`.

This is dependency and cryptographic smoke coverage only: no wallet was opened and no wallet daemon or secret service was started. Pipelines **#107** and **#108** were not accepted and saved no rootfs cache: #107 polluted QCA's qmake-derived paths under the POSIX locale, and #108 used `gcrypt.pc` instead of `libgcrypt.pc` in the post-install check. They must not be rerun. Security-deps1 is accepted only through corrected pipeline #109 and must not be rerun. Plasma remains absent and `BOOTABLE=no` is unchanged.
