# ESRP Signing Investigation — AZL4 Beta PMC Publishing

Source: e-mail "FW: AZL4 Beta PMC publishing status" (Andrew Phelps → Pawel
Winogrodzki, 2026-05-05). The list below is the table extracted verbatim from
the section **"Specific list of RPMs that failed to sign:"**, followed by a
mapping of each failing RPM to the corresponding component definition in this
repository.

The signing failures are caused by malware-scan hits during ESRP signing of
AZL4 Alpha2 RPMs that are being published to PMC AZL4 Beta repos.

This document is now also the **top-level progress tracker** for the
investigation. The per-component status rollup (originally in
`investigation/STATUS.md`) lives here, alongside the live ESRP scanner
detection data and the original RPM-to-component mapping. Per-component
authoritative state still lives in `investigation/<component>/progress.md`;
this file is the navigation summary.

## Policy (2026-05-07)

Two hard constraints govern every component report and every Mitigation
recommendation in this investigation:

1. **No ESRP allow-listing.** Allow-listing on the ESRP side / scanner
   exceptions / path-scoped waivers are NOT acceptable mitigations. Every
   `## Mitigation feasibility` bullet in every per-component `progress.md`
   must describe a **component-level change** (Source0 repack via a
   checked-in `modify_source.sh`, dropping a `%package` declaration,
   suppressing an auto-generated subpackage via
   `%global debug_package %{nil}`, flipping a `%bcond`, dropping a
   `Source<N>:` directive, editing `%prep`/`%check` via overlay, etc.).
2. **Flaky scanner.** The 2026-05-06 dump in
   `investigation/file_scans.md` is incomplete \u2014 the scanner's delivery
   mechanism drops detections. **Absence of detection rows for a
   component is NOT evidence the RPM is passing.** Every RPM listed in
   `pkg_results.txt` is genuinely failing ESRP signing; the only
   question is whether a specific scanner-data row is currently captured.
   Verdicts that rest on "no scanner-data hits" must stay `Pending` with
   an explicit Justification caveat and an Open question requesting
   fresh scanner output.

The `No mitigation needed \u2014 passed re-scan` enum value is reserved for
components with a dated, cited re-scan event (e.g. the 2026-05-05
`pkg_results.txt` row dropping the RPM). \"Probably fine because no
scanner data\" does NOT qualify.

A re-audit is in progress to refresh every `progress.md` that pre-dates
this policy; legacy reports may still mention "ESRP allow-list" as a
mitigation \u2014 those mentions are non-binding and will be replaced with
component-level fixes as part of the re-audit.

---

## Per-component investigation status rollup

Mirror of per-component `progress.md` files. The authoritative status for
any single component lives in `investigation/<component>/progress.md`;
the table below is a navigation summary.

| Component | Status | Owner | PR | V1 verdict | File |
|---|---|---|---|---|---|
| `apache-commons-compress` | In progress | unassigned | none | True positive shape, benign content — SRPM-only failure; `src/test/resources/` is the entire Apache Commons Compress defensive-parser regression corpus (zip-bombs, corrupt 7z/tar/zip, `*-fail.tar` family, fuzz crashes incl. hash-named `/fuzz/crash-*`, encrypted archives, bundled Eclipse 3.2 runtime with signed JARs + 2 ELF `.so` blobs, PyPI orjson sdist, Pack200 fixture carrying entire Apache Ant `.class` codebase, Android `.apk` debug builds). No `%check`, only `%files -f .mfiles`. **Canonical fix**: Source0 repack via a checked-in `modify_source.sh` (modeled on `base/comps/yara/modify_source.sh`) stripping `src/test/resources/`. Tracked under ADO #19805 for the long-term `azldev`/TOML-native source-modification migration. 2026-05-06 scanner data confirmed `bla.encrypted.7z` + `password-encrypted.zip` as live trip points. | [progress](investigation/apache-commons-compress/progress.md) |
| `chromium` | Done | pawelwi | none | Removed (component not in repo) | [progress](investigation/chromium/progress.md) |
| `espeak-ng` | In progress | unassigned | none | True positive shape, benign content — `tests/ssml/billion-laughs.ssml` + `external-entity.ssml` are literal XXE/XML-bomb payloads, plus SHA1-named SSML fuzzer corpus, hundreds of `phsource/` PECTSEQ binary blobs + ~150 consonant `.wav` samples (genuine voice-synthesis source compiled into `%{_datadir}/espeak-ng-data/`), `src/windows/Debug/output_*.wav`, `android/`, `chromium_extension/`. None ship to runtime; **canonical fix**: vendored Source0 repack via a checked-in `modify_source.sh` stripping `tests/ssml{,-fuzzer}/`, `src/windows/`, `chromium_extension/`, `android/` (low risk; `%check` is provably no-op). For `phsource/` PECTSEQ + WAV sources: pre-compile into binary `espeak-ng-data/` at tarball-rolling time (Option A) or escalate as Critical if the runtime payload also trips the heuristic. Tracked under ADO #19805. | [progress](investigation/espeak-ng/progress.md) |
| `exfatprogs` | In progress | unassigned | none | True positive shape, benign content — 19 `tests/<scenario>/exfat.img.tar.xz` deliberately-corrupted exFAT images (bad_bitmap, bad_dentries, bs_bad_csum, loop_chain, etc.) + `tests/upcase_table/` shell scripts; `tests/` is `EXTRA_DIST`-only and spec has no `%check`. **Canonical fix**: Source0 repack via a checked-in `modify_source.sh` (modeled on `base/comps/yara/modify_source.sh`) stripping `tests/`. Low risk because `tests/` is `EXTRA_DIST`-only, no coverage impact. Tracked under ADO #19805. | [progress](investigation/exfatprogs/progress.md) |
| `firefox` | In progress | unassigned | none | True positive shape, benign content — SRPM-only failure; Source0 ships malformed media/image/font crashtest corpora, `pip`/`setuptools` Windows PE launcher stubs, vendored third-party PE/corrupt-gz fixtures, `third_party/chromium/build/android/tests/symbolize/lib{a,b}.so`. Source3 (`dump_syms-vendor`) ships Windows PE/PDB; Source37 (`mochitest-python`) ships bundled `setuptools-50.3.2.zip` wininst PE stubs; Source50 (`wasi-sdk-25`) ships LLVM clang Driver-test PE inputs + ~190 Android NDK ELF `.so` stubs. None reach binary RPMs (`build_tests=0`, `run_firefox_tests=0`, `enable_mozilla_crashreporter=0`). **Canonical fixes**: drop `Source3` + `Source37` (low risk, both gated dead weight); strip `Source50/clang/test/` (medium risk); Source0 repack via a checked-in `modify_source.sh`. Tracked under ADO #19805. | [progress](investigation/firefox/progress.md) |
| `gdal` | In progress | unassigned | none | False positive — all hits trace to `gdalautotest-3.11.5.tar.gz` (Source1) test-fixture zoo (incl. SOZip-of-SOZip 5GiB zero-bomb); `%check` is hard-disabled, so dropping Source1 is low-risk. | [progress](investigation/gdal/progress.md) |
| `ghc` | In progress | unassigned | none | False positive (likely). 2 binary subpackages (`ghc-ghc-prof-9.8.4-149.azl4~20260420.{x86_64,aarch64}.rpm`) failing; sister `ghc-ghc-devel.aarch64` passed re-scan. Each failing RPM ships 752 small `*.p_hi` profiling-interface files plus one large `libHSghc-9.8.4-<hash>_p.a` profiling-flavour static archive — same entropy-heuristic shape family as the openfec debuginfo case. **Canonical fix**: set `%bcond perfbuild 0` (or `%undefine with_ghc_prof`) in `specs/g/ghc/ghc.spec` line 7 / line 15 to suppress generation of the `ghc-ghc-prof` subpackage entirely. Cost: downstream Haskell consumers cannot build with `+prof`. Per the 2026-05-07 policy, Pending verdicts reflect that absence of detection rows in `file_scans.md` does NOT mean the RPM is passing — the scanner is flaky. | [progress](investigation/ghc/progress.md) |
| `java-25-openjdk` | In progress | unassigned | none | False positive (likely). 2 binary subpackages (`java-25-openjdk-static-libs-slowdebug-25.0.0.0.32-0.3.ea.azl4~20260420.{x86_64,aarch64}.rpm`) failing. **Canonical fix**: flip `%bcond_without slowdebug` to `%bcond_with slowdebug` in `specs/j/java-25-openjdk/java-25-openjdk.spec` (or drop `%package static-libs-slowdebug` outright) to suppress the failing sub-package. **Twin investigation with `java-25-openjdk-portable`** — same upstream tarball, same gating, identical `.a` bytes; the same toggle must be flipped on both spec files. NOTE: `java-25-openjdk` does NOT have a `package_files.md` (only the 29 other tracked components do); flagged for orchestrator regeneration. Per the 2026-05-07 policy, Pending verdicts reflect flaky-scanner uncertainty rather than any pass signal. | [progress](investigation/java-25-openjdk/progress.md) |
| `java-25-openjdk-portable` | In progress | unassigned | none | False positive (likely). 2 binary subpackages (`java-25-openjdk-portable-static-libs-slowdebug-25.0.0.0.32-0.1.ea.azl4~20260420.{x86_64,aarch64}.rpm`) failing. Twin of `java-25-openjdk` — same upstream `openjdk-25+32-ea.tar.xz` tarball, same slowdebug+staticlibs `%files` gating, identical `.a` bytes; only the RPM payload layout differs. `package_files.md` confirms only `.a` static archives + `.sha256sum` ship in the failing RPM payload. **Canonical fix**: flip `%bcond_without slowdebug` to `%bcond_with slowdebug` (or drop `%package static-libs-slowdebug`) on both `specs/j/java-25-openjdk*/` spec files in coordination. | [progress](investigation/java-25-openjdk-portable/progress.md) |
| `kf6-karchive` | In progress | unassigned | none | False positive at binary-RPM layer, true positive at SRPM layer — upstream `autotests/data/` ships intentionally-malformed zip64 fixtures (e.g. `zip64_extra_zip64_size_first.zip.gz`); no `%check` block, no autotest in any `%files`. **Canonical fix**: Source0 repack via checked-in `modify_source.sh` stripping `autotests/data/` (medium risk). Tracked under ADO #19805. 2026-05-06 scanner data confirmed `password_protected.7z` as a live trip point. | [progress](investigation/kf6-karchive/progress.md) |
| `libabigail` | Done | orchestrator | none | Failing SRPM passed ESRP re-scan (per pkg_results.txt 2026-05-05) | [progress](investigation/libabigail/progress.md) |
| `libkml` | In progress | unassigned | none | True positive shape, benign content (Pending verdicts — the 2026-05-06 `file_scans.md` dump is incomplete; absence of detections is NOT a pass signal). Most plausible triggers are `testdata/kmz/{bad*,overflow_*,zermatt-photo-bad}.kmz` (8 deliberately-corrupted KMZ archives, names enumerate the minizip parser bugs they exercise) and `testdata/kml/billion.kml` plus deeply-nested-element KML fixtures. Bundled-minizip (Source0 + Source1) is plain C source. **Canonical fix**: Source0 repack via checked-in `modify_source.sh` stripping the malformed `testdata/kmz/` and adversarial-XML `testdata/kml/` fixtures. `%check %ctest` consumes `testdata/`, so this is medium risk. Tracked under ADO #19805. | [progress](investigation/libkml/progress.md) |
| `llvm` | Not started | unassigned | none | — | [progress](investigation/llvm/progress.md) |
| `llvm20` | Not started | unassigned | none | — | [progress](investigation/llvm20/progress.md) |
| `mathjax` | Done | orchestrator | none | Failing SRPM passed ESRP re-scan (per pkg_results.txt 2026-05-05) | [progress](investigation/mathjax/progress.md) |
| `mingw-gettext` | Done | orchestrator | none | Failing RPM passed ESRP re-scan (per pkg_results.txt 2026-05-05) | [progress](investigation/mingw-gettext/progress.md) |
| `mingw-libxml2` | Done | orchestrator | none | Failing RPM passed ESRP re-scan (per pkg_results.txt 2026-05-05) | [progress](investigation/mingw-libxml2/progress.md) |
| `mozjs128` | In progress | unassigned | none | True positive shape, benign content. 1 live K7 detection (`aes_archive.zip` at `firefox-128.11.0esr.source.tar.xz/firefox-128.11.0/third_party/rust/zip/tests/data/`) is a tautological false positive on the Rust `zip` crate's AES test fixture. SRPM ships the entire upstream Firefox tarball but `%build` consumes only `js/src/`; everything outside is dead weight. **Canonical fix**: Source0 repack via a checked-in `modify_source.sh` (modeled on `base/comps/yara/modify_source.sh`) keeping only `js/`, `build/`, `config/`, `mfbt/`, `memory/`, `mozglue/`, `python/mozbuild/`, `LICENSE`, `Cargo.{toml,lock}`, `moz.configure` and dropping every other top-level subtree (incl. `js/src/fuzz-tests/` which would otherwise survive a naive `js/`-only filter). Tracked under ADO #19805. | [progress](investigation/mozjs128/progress.md) |
| `openfec` | In progress | unassigned | none | False positive on both failing RPMs. Karambiner `packer_high_entropy:eod` fires on the auto-generated `usr/lib/debug/usr/lib64/libopenfec.so.1.4.2-...{x86_64,aarch64}.debug` ELFs produced by rpmbuild's `find-debuginfo.sh`+`dwz` pipeline. High DWARF entropy (`--compress-debug-sections=zlib`) is intrinsic. **Canonical fix LANDED** on branch `pawelwi/openfec-disable-debuginfo` (commit `1c68d4149a`): a `spec-search-replace` overlay in `base/comps/openfec/openfec.comp.toml` injecting `%global debug_package %{nil}` before the `Name:` line, suppressing `*-debuginfo` subpackage generation entirely. Trade-off: loses post-mortem `gdb`/`crash` debugging for `libopenfec.so.1.4.2`. Fallback: build-time `-gz=none` via CFLAGS for uncompressed DWARF (medium risk, larger debuginfo). | [progress](investigation/openfec/progress.md) |
| `perl-Module-Signature` | Done | orchestrator | none | Failing SRPM + noarch RPM passed ESRP re-scan (per pkg_results.txt 2026-05-05) | [progress](investigation/perl-Module-Signature/progress.md) |
| `perl-Test-Signature` | Done | orchestrator | none | Failing SRPM + noarch RPM passed ESRP re-scan (2026-05-05); confirmed clear again on 2026-05-06 re-run (no scanner detections in `investigation/file_scans.md`). | [progress](investigation/perl-Test-Signature/progress.md) |
| `python-impacket` | In progress | anphel | [#17040](https://github.com/microsoft/azurelinux/pull/17040) | Component being removed entirely; only consumer (`curl` BuildRequires for upstream test 1451) is also dropped. | [progress](investigation/python-impacket/progress.md) |
| `qemu` | In progress | unassigned | none | True positive shape, benign content (Pending verdicts — the 2026-05-06 `file_scans.md` dump is incomplete; absence of detections is NOT a pass signal). 2 binary subpackages (`qemu-tests-10.1.4-1.azl4~20260420.{x86_64,aarch64}.rpm`) failing. The `qemu-tests` subpackage ships the QEMU regression test corpus: 16 `sample_images/*.bz2` deliberately-corrupted disk images, golden `.qcow2`/`.raw` outputs, a `grub_mbr.raw.bz2` real-x86 MBR boot-sector blob, and 29 `accel-qtest-*.so` ELF qtest plugins. **Canonical fix**: drop the `%package tests` declaration (loses the `qemu-tests-src` install but `make check` from SRPM still works). Fallback: medium-risk Source0 strip of `tests/data/` via checked-in `modify_source.sh`. | [progress](investigation/qemu/progress.md) |
| `qt6-qtwebengine` | In progress | unassigned | none | True positive shape, benign content. 14 unique K7 `File is encrypted!` detections on bundled-chromium test fixtures: 12 in `src/3rdparty/chromium/third_party/libzip/src/regress/*.zip` (libzip AES/PKWARE crypto fixtures) + 2 in `src/3rdparty/chromium/third_party/lzma_sdk/google/test_data/encrypted{,_header}.7z`. None compiled in AZL: spec uses `use_system_minizip 1`, no `%check`. Pending rows for ~190 V8/Blink fuzz_corpus blobs, batched chromium fuzz corpora (cast/HID/USB/CORS/viz), AVIF/MP4/HEVC fixtures, breakpad/crashpad PE blobs. **Canonical fix**: extend `clean_qtwebengine.sh` (already strips ffmpeg + openh264) with `rm -rf` for the offending fixture trees — multi-step (edit script → re-roll tarball → new SHA512 → update `sources` → bump `Release:`). Tracked under ADO #19805. | [progress](investigation/qt6-qtwebengine/progress.md) |
| `rubygem-pdf-reader` | Not started | unassigned | none | — | [progress](investigation/rubygem-pdf-reader/progress.md) |
| `samba` | Not started | unassigned | none | — | [progress](investigation/samba/progress.md) |
| `star` | Not started | unassigned | none | — | [progress](investigation/star/progress.md) |
| `stress-ng` | Done | orchestrator | none | Failing SRPM passed ESRP re-scan (per pkg_results.txt 2026-05-05) | [progress](investigation/stress-ng/progress.md) |
| `texlive` | Not started | unassigned | none | — | [progress](investigation/texlive/progress.md) |
| `yara` | In progress | unassigned | none | True positive shape, benign content — `tests/oss-fuzz/dotnet_fuzzer_corpus/obfuscated` is a deliberately-obfuscated .NET binary used as YARA's own oss-fuzz seed corpus. Per the 2026-05-06 K7 dump, this is THE confirmed live trigger (`packer_dotfuscator:eod`, Karambiner). **Canonical fix LANDED** on branch `pawelwi/yara-strip-obfuscated` (commit `58e3ab7329`): a checked-in `base/comps/yara/modify_source.sh` deterministically strips `tests/oss-fuzz/dotnet_fuzzer_corpus/obfuscated` from Source0 and repacks with stable SHA512 (`57d3388dc9...`). The `base/comps/yara/yara.comp.toml` `source-files` block points at the modified tarball (placeholder URL until the modified tarball is uploaded to the AZL modified-sources blob). Tracked under ADO #19805. | [progress](investigation/yara/progress.md) |

### Summary counts (filled at end of Phase 4)

- Done: 8 (`chromium`, `libabigail`, `mathjax`, `mingw-gettext`, `mingw-libxml2`, `perl-Module-Signature`, `perl-Test-Signature`, `stress-ng`)
- In progress: 16 (`apache-commons-compress`, `espeak-ng`, `exfatprogs`, `firefox`, `gdal`, `ghc`, `java-25-openjdk`, `java-25-openjdk-portable`, `kf6-karchive`, `libkml`, `mozjs128`, `openfec`, `python-impacket`, `qemu`, `qt6-qtwebengine`, `yara`)
- Not started: 6 (`llvm`, `llvm20`, `rubygem-pdf-reader`, `samba`, `star`, `texlive`)
- Blocked: 0
- Critical: 0

Total tracked: 30 components.

### Notes on the rollup

- `chromium` is included even though it has no spec in this repo (the SRPM showed up in the publishing pipeline from an external source). See [investigation/chromium/progress.md](investigation/chromium/progress.md) for the follow-up question.
- `mingw-curl` is intentionally NOT tracked — it does not appear in `pkg_results.txt` (the user clarified mentioning it was a mistake).
- **2026-05-05 re-scan update**: per [pkg_results.txt](pkg_results.txt), the failing-RPM list shrank between the original e-mail report and the re-scan. Seven components passed on re-submission with no spec change and are now closed as `Done`: `libabigail`, `mathjax`, `mingw-gettext`, `mingw-libxml2`, `perl-Module-Signature`, `perl-Test-Signature`, `stress-ng`. One additional sub-RPM passed (`ghc-ghc-devel.aarch64.rpm`) but the parent component `ghc` still has failing `ghc-ghc-prof` RPMs and remains in flight.
- **2026-05-06 re-run update**: external sources confirm `perl-Test-Signature-1.11-35.azl4~20260420.{src,noarch}.rpm` again passed on re-submission — no detections present in `investigation/file_scans.md` for this component.
- **2026-05-06 update**: `package_files.md` (auto-generated recursive RPM file listing) now exists for 30 components and is referenced by `investigation/README.md`, `investigation/FORMAT.md`, and the investigator + rubberduck prompts as an authoritative content source.
- **Remaining components requiring full investigation (6)**: `llvm`, `llvm20`, `rubygem-pdf-reader`, `samba`, `star`, `texlive`. None have 2026-05-06 scanner-data hints captured yet.

---

## Live ESRP scanner detections (2026-05-06)

Captured in [investigation/file_scans.md](investigation/file_scans.md).
Each `## BEGIN MAIL … ## END MAIL` block (or, in the latest dump, each
double-blank-line-separated record) gives one detection. Mappings below
map each unique `(File Name, Sha256)` pair to the failing RPM and source
component, by cross-referencing against `investigation/<comp>/package_files.md`.

The scanner output gives only file names and SHA256 — no path, no source
RPM. The component column below is therefore inferred by **filename match
in the recursive RPM listings** (which are themselves authoritative for
what shipped in each failing artefact); SHA256 confirmation requires a
separate pass that hashes the staged lookaside files.

| File name | SHA256 | Detection | Scanner | Component | Path inside RPM | Reference |
|---|---|---|---|---|---|---|
| `obfuscated` | `fa45ddb2f157940f733707e77e8b856127019691585f3fe19aa77c95c8b58394` | `packer_dotfuscator:eod` | Karambiner | `yara` | `yara-4.5.4.tar.gz/yara-4.5.4/tests/oss-fuzz/dotnet_fuzzer_corpus/obfuscated` | [yara/package_files.md](investigation/yara/package_files.md) line 290 |
| `bla.encrypted.7z` | `17925c6a2e339dcf327686e1316df2715197a91346f24edf5845e27e243e6e13` | `File is encrypted!` | K7 | `apache-commons-compress` | `commons-compress-1.27.1-src.tar.gz/commons-compress-1.27.1-src/src/test/resources/bla.encrypted.7z` | [apache-commons-compress/package_files.md](investigation/apache-commons-compress/package_files.md) line 8741 |
| `password-encrypted.zip` | `3a2559c7157226f1ef08ad5dcb3532e921f41474655d390932096f532f09ad85` | `File is encrypted!` | K7 | `apache-commons-compress` | `commons-compress-1.27.1-src.tar.gz/commons-compress-1.27.1-src/src/test/resources/password-encrypted.zip` | [apache-commons-compress/package_files.md](investigation/apache-commons-compress/package_files.md) line 10556 |
| `password_protected.7z` | `c8189f20e512761085abc594382a853e3bd2683c149871a8e0cd165d4446d7b8` | `File is encrypted!` | K7 | `kf6-karchive` | `karchive-6.23.0.tar.xz/karchive-6.23.0/autotests/data/password_protected.7z` | [kf6-karchive/package_files.md](investigation/kf6-karchive/package_files.md) line 95 |
| `libopenfec.so.1.4.2-1.4.2.6-7.azl4~20260420.x86_64.debug` | `050bb5ee298b5028211a89fe74a608309e77d30c9607896248f200dafdfb3c46` | `packer_high_entropy:eod` | Karambiner | `openfec` | `openfec-debuginfo-1.4.2.6-7.azl4~20260420.x86_64.rpm` payload (auto-generated debuginfo of `libopenfec.so.1.4.2`) | (debuginfo binary; not in any tar/zip — directly inside the failing `*-debuginfo` RPM) |
| `libopenfec.so.1.4.2-1.4.2.6-7.azl4~20260420.aarch64.debug` | `fce98b88caf1b8136d1c44be29527592d1d935bfcbe33af299efb1aa64a9e0f8` | `packer_high_entropy:eod` | Karambiner | `openfec` | `openfec-debuginfo-1.4.2.6-7.azl4~20260420.aarch64.rpm` payload | (debuginfo binary) |
| `broken.zip` | `6786690f390a8ad0e70e38900832332c85b04710c82785a03928e86677b8aaa4` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `qtwebengine-everywhere-src-6.10.2-clean.tar.xz/.../src/3rdparty/chromium/third_party/libzip/src/regress/broken.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180808 |
| `encrypt.zip` | `2a4520f5f179b9f3b7cf2f54385053b3b7d8acefbe0438c2be28eae5412bf0d4` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../src/3rdparty/chromium/third_party/libzip/src/regress/encrypt.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180864 |
| `encrypt-aes128.zip` | `82c67fe36d8ab42cba7455dab0270681694c23ef590fdc3501864b2f4260f858` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt-aes128.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180849 |
| `encrypt-aes128-noentropy.zip` | `774f22ea6c0f2c1015c56c1ea52633a8ca07dfbe96c8b7d320e7ffba9d3be54e` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt-aes128-noentropy.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180847 |
| `encrypt-aes192.zip` | `c259399ea7a1618bd1fc36b17404a16efa0a5e7b40bb395d8d347856fae57790` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt-aes192.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180853 |
| `encrypt-aes192-noentropy.zip` | `a6ec1a039d687b3c52a4b159b78049e066544873db6fca51056bb564daa8fa1d` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt-aes192-noentropy.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180851 |
| `encrypt-aes256.zip` | `6ed6c0645b6270aa1155177484f0c49f8d5194dd8220495867c6ed2fac20ac1c` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt-aes256.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180857 |
| `encrypt-aes256-noentropy.zip` | `b0360dd70d901b3494d3bff3609582329a0005bf7246f80c8d2ede71fd942457` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt-aes256-noentropy.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180855 |
| `encrypt-pkware-noentropy.zip` | `6dff2109ef56179b9d5452490c169c1000e05fdb8ab3a3f5e4284fce04685710` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt-pkware-noentropy.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180861 |
| `encrypt_plus_extra.zip` | `e55abb60d5cb90968e43389514e7bf18b2bd5acdf488d1ca31daff91e5addfb8` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt_plus_extra.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180866 |
| `encrypt_plus_extra_modified_c.zip` | `07475bc28e1971fc1e4977aff26b390cd9fa6d6b65155f64961ba40f6fca74c9` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt_plus_extra_modified_c.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180868 |
| `encrypt_plus_extra_modified_l.zip` | `0b75b5b828d846c714915ca7acff89c7e140049a63e5f71e6a89cda55039948f` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../libzip/src/regress/encrypt_plus_extra_modified_l.zip` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 180870 |
| `encrypted.7z` | `e08da1630dadceed970afb3e4dc3ecc098de05e858e4b11af852b863a2f85178` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../src/3rdparty/chromium/third_party/lzma_sdk/google/test_data/encrypted.7z` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 733432 |
| `encrypted_header.7z` | `fffad602471fa9cede8c5f084c38c47dab92247caea300c15ae19d9e95212b98` | `File is encrypted!` | K7 | `qt6-qtwebengine` | `.../src/3rdparty/chromium/third_party/lzma_sdk/google/test_data/encrypted_header.7z` | [qt6-qtwebengine/package_files.md](investigation/qt6-qtwebengine/package_files.md) line 733433 |
| `aes_archive.zip` | `4abb3f304d1ab669453b7c4eae80db6ce8aff4ab91c8ab9a6edf90bbfede12f4` | `File is encrypted!` | K7 | `mozjs128` | inside `mozjs128-128.11.0-1.azl4~20260420.src.rpm` (path not enumerated — [mozjs128/package_files.md](investigation/mozjs128/package_files.md) listing is incomplete) | per user direction 2026-05-06; needs path confirmation during the `mozjs128` Wave-C investigation |

### Failing RPM → detected file → component

Compact mapping of every failing RPM (from the e-mail's failed-signing list above) to the ESRP-flagged files it ships and the source component. Sorted alphabetically by failing RPM filename. Rows with `—` in *Detected file* had no entry in [investigation/file_scans.md](investigation/file_scans.md) for the 2026-05-06 dump (either the RPM passed re-scan with no spec change, the component is being removed, or the RPM is still failing but has no scanner-data hint captured yet — see the per-component rollup above for status). RPMs with multiple detections occupy multiple rows.

Total: 41 unique failing RPMs → 21 detection rows + 34 no-detection rows = 55 entries (the 7 RPMs with at least one detection account for the 21 detection rows; the remaining 34 RPMs have `—`).

| Failing RPM | Detected file | Component |
|---|---|---|
| `apache-commons-compress-1.27.1-1.azl4~20260420.src.rpm` | `bla.encrypted.7z` | [`apache-commons-compress`](investigation/apache-commons-compress/progress.md) |
| `apache-commons-compress-1.27.1-1.azl4~20260420.src.rpm` | `password-encrypted.zip` | [`apache-commons-compress`](investigation/apache-commons-compress/progress.md) |
| `chromium-145.0.7632.109-1.azl4~20260420.src.rpm` | — | (none — not in this repo) |
| `espeak-ng-1.51.1-12.azl4~20260420.src.rpm` | — | [`espeak-ng`](investigation/espeak-ng/progress.md) |
| `exfatprogs-1.3.1-1.azl4~20260420.src.rpm` | — | [`exfatprogs`](investigation/exfatprogs/progress.md) |
| `firefox-148.0-1.azl4~20260420.src.rpm` | — | [`firefox`](investigation/firefox/progress.md) |
| `gdal-3.11.5-1.azl4~20260420.src.rpm` | — | [`gdal`](investigation/gdal/progress.md) |
| `ghc-ghc-devel-9.8.4-149.azl4~20260420.aarch64.rpm` | — | [`ghc`](investigation/ghc/progress.md) |
| `ghc-ghc-prof-9.8.4-149.azl4~20260420.aarch64.rpm` | — | [`ghc`](investigation/ghc/progress.md) |
| `ghc-ghc-prof-9.8.4-149.azl4~20260420.x86_64.rpm` | — | [`ghc`](investigation/ghc/progress.md) |
| `java-25-openjdk-portable-static-libs-slowdebug-25.0.0.0.32-0.1.ea.azl4~20260420.aarch64.rpm` | — | [`java-25-openjdk-portable`](investigation/java-25-openjdk-portable/progress.md) |
| `java-25-openjdk-portable-static-libs-slowdebug-25.0.0.0.32-0.1.ea.azl4~20260420.x86_64.rpm` | — | [`java-25-openjdk-portable`](investigation/java-25-openjdk-portable/progress.md) |
| `java-25-openjdk-static-libs-slowdebug-25.0.0.0.32-0.3.ea.azl4~20260420.aarch64.rpm` | — | [`java-25-openjdk`](investigation/java-25-openjdk/progress.md) |
| `java-25-openjdk-static-libs-slowdebug-25.0.0.0.32-0.3.ea.azl4~20260420.x86_64.rpm` | — | [`java-25-openjdk`](investigation/java-25-openjdk/progress.md) |
| `kf6-karchive-6.23.0-1.azl4~20260420.src.rpm` | `password_protected.7z` | [`kf6-karchive`](investigation/kf6-karchive/progress.md) |
| `libabigail-2.9-1.azl4~20260420.src.rpm` | — | [`libabigail`](investigation/libabigail/progress.md) |
| `libkml-1.3.0-56.azl4~20260420.src.rpm` | — | [`libkml`](investigation/libkml/progress.md) |
| `llvm-static-21.1.8-1.azl4~20260420.aarch64.rpm` | — | [`llvm`](investigation/llvm/progress.md) |
| `llvm20-static-20.1.8-1.azl4~20260420.aarch64.rpm` | — | [`llvm20`](investigation/llvm20/progress.md) |
| `llvm20-static-20.1.8-1.azl4~20260420.x86_64.rpm` | — | [`llvm20`](investigation/llvm20/progress.md) |
| `mathjax-2.7.4-1.azl4~20260420.src.rpm` | — | [`mathjax`](investigation/mathjax/progress.md) |
| `mingw64-gettext-static-0.25.1-1.azl4~20260420.noarch.rpm` | — | [`mingw-gettext`](investigation/mingw-gettext/progress.md) |
| `mingw64-libxml2-static-2.12.10-2.azl4~20260420.noarch.rpm` | — | [`mingw-libxml2`](investigation/mingw-libxml2/progress.md) |
| `mozjs128-128.11.0-1.azl4~20260420.src.rpm` | `aes_archive.zip` | [`mozjs128`](investigation/mozjs128/progress.md) |
| `openfec-debuginfo-1.4.2.6-7.azl4~20260420.aarch64.rpm` | `libopenfec.so.1.4.2-1.4.2.6-7.azl4~20260420.aarch64.debug` | [`openfec`](investigation/openfec/progress.md) |
| `openfec-debuginfo-1.4.2.6-7.azl4~20260420.x86_64.rpm` | `libopenfec.so.1.4.2-1.4.2.6-7.azl4~20260420.x86_64.debug` | [`openfec`](investigation/openfec/progress.md) |
| `perl-Module-Signature-0.93-2.azl4~20260420.noarch.rpm` | — | [`perl-Module-Signature`](investigation/perl-Module-Signature/progress.md) |
| `perl-Module-Signature-0.93-2.azl4~20260420.src.rpm` | — | [`perl-Module-Signature`](investigation/perl-Module-Signature/progress.md) |
| `perl-Test-Signature-1.11-35.azl4~20260420.noarch.rpm` | — | [`perl-Test-Signature`](investigation/perl-Test-Signature/progress.md) |
| `perl-Test-Signature-1.11-35.azl4~20260420.src.rpm` | — | [`perl-Test-Signature`](investigation/perl-Test-Signature/progress.md) |
| `python-impacket-0.12.0-1.azl4~20260420.src.rpm` | — | [`python-impacket`](investigation/python-impacket/progress.md) |
| `python3-impacket-0.12.0-1.azl4~20260420.noarch.rpm` | — | [`python-impacket`](investigation/python-impacket/progress.md) |
| `qemu-tests-10.1.4-1.azl4~20260420.aarch64.rpm` | — | [`qemu`](investigation/qemu/progress.md) |
| `qemu-tests-10.1.4-1.azl4~20260420.x86_64.rpm` | — | [`qemu`](investigation/qemu/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `broken.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt-aes128-noentropy.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt-aes128.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt-aes192-noentropy.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt-aes192.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt-aes256-noentropy.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt-aes256.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt-pkware-noentropy.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt_plus_extra.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt_plus_extra_modified_c.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypt_plus_extra_modified_l.zip` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypted.7z` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | `encrypted_header.7z` | [`qt6-qtwebengine`](investigation/qt6-qtwebengine/progress.md) |
| `rubygem-pdf-reader-2.4.2-10.azl4~20260420.src.rpm` | — | [`rubygem-pdf-reader`](investigation/rubygem-pdf-reader/progress.md) |
| `samba-winexe-4.23.5-1.azl4~20260420.aarch64.rpm` | — | [`samba`](investigation/samba/progress.md) |
| `samba-winexe-4.23.5-1.azl4~20260420.x86_64.rpm` | — | [`samba`](investigation/samba/progress.md) |
| `star-1.6-18.azl4~20260420.src.rpm` | — | [`star`](investigation/star/progress.md) |
| `stress-ng-0.20.01-1.azl4~20260420.src.rpm` | — | [`stress-ng`](investigation/stress-ng/progress.md) |
| `texlive-2023-80.azl4~20260420.src.rpm` | — | [`texlive`](investigation/texlive/progress.md) |
| `yara-4.5.4-1.azl4~20260420.src.rpm` | `obfuscated` | [`yara`](investigation/yara/progress.md) |

### Aggregate detection summary

- **21 unique detections** in [investigation/file_scans.md](investigation/file_scans.md) (some appear multiple times across different ESRP request IDs; deduplicated by `(File Name, Sha256)`).
- **Two distinct detection signatures**:
  - `File is encrypted!` (K7) — fires on password-protected / AES-encrypted ZIP and 7z archives (19 of 21 detections). Always a benign positive on test-fixture content; AV scanners cannot inspect encrypted archives and surface them as "unable to scan".
  - `packer_dotfuscator:eod` and `packer_high_entropy:eod` (Karambiner) — fires on entropy/packer heuristics. The `dotfuscator` hit is on a deliberately-obfuscated .NET test binary in YARA's fuzzer corpus (true positive — that is exactly what the file is). The `packer_high_entropy` hits are on the openfec `*-debuginfo` `.debug` companion ELFs — almost certainly a false positive on stripped DWARF/symbol-table data, which is naturally high-entropy.
- **Distribution by component**: `qt6-qtwebengine` 14 detections (12 libzip + 2 lzma_sdk; counted by unique `(File Name, Sha256)`), `apache-commons-compress` 2, `openfec` 2, `mozjs128` 1, `kf6-karchive` 1, `yara` 1.

### Cross-cutting observations

- All but two detections are on **bundled-third-party encrypted-archive test fixtures** with the scanner refusing to inspect them. This is a single class of false-positive that should be addressable by a single ESRP allow-list rule (or by SRPM-time strip of the relevant `tests/`/`regress/`/`test_data/` directories).
- The `openfec` `*.debug` detections are a **distinct class** (entropy heuristic on stripped debug ELFs, not encrypted archives). Likely false positive but needs a different mitigation: ESRP allow-list scoped to `*-debuginfo` packages, or rebuild with different `--strip-debug-symbols` flags. Worth checking whether other `*-debuginfo` packages in the AZL fleet were also flagged but suppressed by the publishing pipeline.
- The YARA `obfuscated` hit (`packer_dotfuscator`) is the strongest classification any of the scanners produced — it correctly identifies the file as a Dotfuscator-packed .NET binary, which is precisely what YARA's `dotnet_fuzzer_corpus/obfuscated` is supposed to be (a deliberately-obfuscated input for the YARA `.NET` parser). Useful as an exemplar of "scanner working correctly on benign test data".
- **No detection citations** for: `chromium` (unmapped — its detections may live in a separate scan run), `espeak-ng` (no detections in 2026-05-06 dump despite the SSML XXE/billion-laughs payloads being a strong trigger candidate — re-check in next dump), `exfatprogs`, `firefox`, `gdal`, `ghc`, `java-25-openjdk*`, `libabigail` (passed re-scan), `libkml`, `llvm`/`llvm20`, `mathjax` (passed re-scan), `mingw-*` (passed re-scan), `perl-*-Signature` (passed re-scan), `python-impacket` (being removed), `qemu`, `rubygem-pdf-reader`, `samba`, `star`, `stress-ng` (passed re-scan), `texlive`. The 2026-05-06 dump may be partial — additional detections may surface in subsequent runs.

---

## Failed-signing table (from the e-mail)

| Alpha2 Repo | # Failed signing | RPM signing failures |
|---|---:|---|
| `base/x86_64` | 2 | `perl-Module-Signature-0.93-2.azl4~20260420.noarch.rpm`<br>`samba-winexe-4.23.5-1.azl4~20260420.x86_64.rpm` |
| `base/aarch64` | 3 | `llvm-static-21.1.8-1.azl4~20260420.aarch64.rpm`<br>`perl-Module-Signature-0.93-2.azl4~20260420.noarch.rpm`<br>`samba-winexe-4.23.5-1.azl4~20260420.aarch64.rpm` |
| `base/srpms` | 20 | `apache-commons-compress-1.27.1-1.azl4~20260420.src.rpm`<br>`chromium-145.0.7632.109-1.azl4~20260420.src.rpm`<br>`espeak-ng-1.51.1-12.azl4~20260420.src.rpm`<br>`exfatprogs-1.3.1-1.azl4~20260420.src.rpm`<br>`firefox-148.0-1.azl4~20260420.src.rpm`<br>`gdal-3.11.5-1.azl4~20260420.src.rpm`<br>`kf6-karchive-6.23.0-1.azl4~20260420.src.rpm`<br>`libabigail-2.9-1.azl4~20260420.src.rpm`<br>`libkml-1.3.0-56.azl4~20260420.src.rpm`<br>`mathjax-2.7.4-1.azl4~20260420.src.rpm`<br>`mozjs128-128.11.0-1.azl4~20260420.src.rpm`<br>`perl-Module-Signature-0.93-2.azl4~20260420.src.rpm`<br>`perl-Test-Signature-1.11-35.azl4~20260420.src.rpm`<br>`python-impacket-0.12.0-1.azl4~20260420.src.rpm`<br>`qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm`<br>`rubygem-pdf-reader-2.4.2-10.azl4~20260420.src.rpm`<br>`star-1.6-18.azl4~20260420.src.rpm`<br>`stress-ng-0.20.01-1.azl4~20260420.src.rpm`<br>`texlive-2023-80.azl4~20260420.src.rpm`<br>`yara-4.5.4-1.azl4~20260420.src.rpm` |
| `base/debuginfo/x86_64` | 0 | None |
| `base/debuginfo/aarch64` | 0 | None |
| `sdk/x86_64` | 9 | `ghc-ghc-prof-9.8.4-149.azl4~20260420.x86_64.rpm`<br>`java-25-openjdk-portable-static-libs-slowdebug-25.0.0.0.32-0.1.ea.azl4~20260420.x86_64.rpm`<br>`java-25-openjdk-static-libs-slowdebug-25.0.0.0.32-0.3.ea.azl4~20260420.x86_64.rpm`<br>`llvm20-static-20.1.8-1.azl4~20260420.x86_64.rpm`<br>`mingw64-gettext-static-0.25.1-1.azl4~20260420.noarch.rpm`<br>`mingw64-libxml2-static-2.12.10-2.azl4~20260420.noarch.rpm`<br>`perl-Test-Signature-1.11-35.azl4~20260420.noarch.rpm`<br>`python3-impacket-0.12.0-1.azl4~20260420.noarch.rpm`<br>`qemu-tests-10.1.4-1.azl4~20260420.x86_64.rpm` |
| `sdk/aarch64` | 10 | `ghc-ghc-devel-9.8.4-149.azl4~20260420.aarch64.rpm`<br>`ghc-ghc-prof-9.8.4-149.azl4~20260420.aarch64.rpm`<br>`java-25-openjdk-portable-static-libs-slowdebug-25.0.0.0.32-0.1.ea.azl4~20260420.aarch64.rpm`<br>`java-25-openjdk-static-libs-slowdebug-25.0.0.0.32-0.3.ea.azl4~20260420.aarch64.rpm`<br>`llvm20-static-20.1.8-1.azl4~20260420.aarch64.rpm`<br>`mingw64-gettext-static-0.25.1-1.azl4~20260420.noarch.rpm`<br>`mingw64-libxml2-static-2.12.10-2.azl4~20260420.noarch.rpm`<br>`perl-Test-Signature-1.11-35.azl4~20260420.noarch.rpm`<br>`python3-impacket-0.12.0-1.azl4~20260420.noarch.rpm`<br>`qemu-tests-10.1.4-1.azl4~20260420.aarch64.rpm` |
| `sdk/srpms` | N/A | N/A |
| `sdk/debuginfo/x86_64` | 1 | `openfec-debuginfo-1.4.2.6-7.azl4~20260420.x86_64.rpm` |
| `sdk/debuginfo/aarch64` | 1 | `openfec-debuginfo-1.4.2.6-7.azl4~20260420.aarch64.rpm` |

---

## RPM → component mapping

Each failing RPM is mapped to the SRPM-level component (i.e. the spec file)
that produces it. Sub-packages and `-debuginfo` packages are mapped to their
parent spec. Versions in the rendered specs were verified to match the version
in each failing RPM.

| Failing RPM file name | Type | Component | Spec file | Notes |
|---|---|---|---|---|
| `apache-commons-compress-1.27.1-1.azl4~20260420.src.rpm` | SRPM | `apache-commons-compress` | [specs/a/apache-commons-compress/apache-commons-compress.spec](specs/a/apache-commons-compress/apache-commons-compress.spec) | Direct. |
| `espeak-ng-1.51.1-12.azl4~20260420.src.rpm` | SRPM | `espeak-ng` | [specs/e/espeak-ng/espeak-ng.spec](specs/e/espeak-ng/espeak-ng.spec) | Direct. |
| `exfatprogs-1.3.1-1.azl4~20260420.src.rpm` | SRPM | `exfatprogs` | [specs/e/exfatprogs/exfatprogs.spec](specs/e/exfatprogs/exfatprogs.spec) | Direct (Version 1.3.1). |
| `firefox-148.0-1.azl4~20260420.src.rpm` | SRPM | `firefox` | [specs/f/firefox/firefox.spec](specs/f/firefox/firefox.spec) | Direct (Version 148.0). |
| `gdal-3.11.5-1.azl4~20260420.src.rpm` | SRPM | `gdal` | [specs/g/gdal/gdal.spec](specs/g/gdal/gdal.spec) | Direct (Version 3.11.5). |
| `ghc-ghc-devel-9.8.4-149.azl4~20260420.aarch64.rpm` | binary subpackage | `ghc` | [specs/g/ghc/ghc.spec](specs/g/ghc/ghc.spec) | Subpackage `ghc-ghc-devel`; same SRPM as `ghc-ghc-prof`. |
| `ghc-ghc-prof-9.8.4-149.azl4~20260420.aarch64.rpm` | binary subpackage | `ghc` | [specs/g/ghc/ghc.spec](specs/g/ghc/ghc.spec) | aarch64 build of the `ghc-ghc-prof` subpackage; `Version: 9.8.4` matches. |
| `ghc-ghc-prof-9.8.4-149.azl4~20260420.x86_64.rpm` | binary subpackage | `ghc` | [specs/g/ghc/ghc.spec](specs/g/ghc/ghc.spec) | x86_64 build of the `ghc-ghc-prof` subpackage (the GHC compiler library's profiling artefacts); `Version: 9.8.4` matches. |
| `java-25-openjdk-static-libs-slowdebug-25.0.0.0.32-0.3.ea.azl4~20260420.aarch64.rpm` | binary subpackage | `java-25-openjdk` | [specs/j/java-25-openjdk/java-25-openjdk.spec](specs/j/java-25-openjdk/java-25-openjdk.spec) | aarch64 build of the "slowdebug" `static-libs` subpackage of the OpenJDK 25 EA build. |
| `java-25-openjdk-static-libs-slowdebug-25.0.0.0.32-0.3.ea.azl4~20260420.x86_64.rpm` | binary subpackage | `java-25-openjdk` | [specs/j/java-25-openjdk/java-25-openjdk.spec](specs/j/java-25-openjdk/java-25-openjdk.spec) | x86_64 build of the "slowdebug" `static-libs` subpackage of the OpenJDK 25 EA build. |
| `java-25-openjdk-portable-static-libs-slowdebug-25.0.0.0.32-0.1.ea.azl4~20260420.aarch64.rpm` | binary subpackage | `java-25-openjdk-portable` | [specs/j/java-25-openjdk-portable/java-25-openjdk-portable.spec](specs/j/java-25-openjdk-portable/java-25-openjdk-portable.spec) | aarch64 build of the "slowdebug" `static-libs` subpackage of the OpenJDK 25 EA "portable" variant SRPM. |
| `java-25-openjdk-portable-static-libs-slowdebug-25.0.0.0.32-0.1.ea.azl4~20260420.x86_64.rpm` | binary subpackage | `java-25-openjdk-portable` | [specs/j/java-25-openjdk-portable/java-25-openjdk-portable.spec](specs/j/java-25-openjdk-portable/java-25-openjdk-portable.spec) | x86_64 build of the "slowdebug" `static-libs` subpackage of the OpenJDK 25 EA "portable" variant SRPM. |
| `kf6-karchive-6.23.0-1.azl4~20260420.src.rpm` | SRPM | `kf6-karchive` | [specs/k/kf6-karchive/kf6-karchive.spec](specs/k/kf6-karchive/kf6-karchive.spec) | Direct. |
| `libabigail-2.9-1.azl4~20260420.src.rpm` | SRPM | `libabigail` | [specs/l/libabigail/libabigail.spec](specs/l/libabigail/libabigail.spec) | Direct. |
| `libkml-1.3.0-56.azl4~20260420.src.rpm` | SRPM | `libkml` | [specs/l/libkml/libkml.spec](specs/l/libkml/libkml.spec) | Direct. |
| `llvm-static-21.1.8-1.azl4~20260420.aarch64.rpm` | binary subpackage | `llvm` | [specs/l/llvm/llvm.spec](specs/l/llvm/llvm.spec) | `%global maj_ver 21 / min_ver 1 / patch_ver 8`; main build → `pkg_name_llvm = llvm`, so subpackage is `llvm-static`. |
| `llvm20-static-20.1.8-1.azl4~20260420.aarch64.rpm` | binary subpackage | `llvm20` | [specs/l/llvm20/llvm20.spec](specs/l/llvm20/llvm20.spec) | aarch64 build; compat build (`pkg_name_llvm = llvm%{maj_ver}` = `llvm20` → subpackage `llvm20-static`). `maj/min/patch = 20/1/8`. |
| `llvm20-static-20.1.8-1.azl4~20260420.x86_64.rpm` | binary subpackage | `llvm20` | [specs/l/llvm20/llvm20.spec](specs/l/llvm20/llvm20.spec) | x86_64 build; compat build (`pkg_name_llvm = llvm%{maj_ver}` = `llvm20` → subpackage `llvm20-static`). `maj/min/patch = 20/1/8`. |
| `mathjax-2.7.4-1.azl4~20260420.src.rpm` | SRPM | `mathjax` | [specs/m/mathjax/mathjax.spec](specs/m/mathjax/mathjax.spec) | Direct (Version 2.7.4). |
| `mingw64-gettext-static-0.25.1-1.azl4~20260420.noarch.rpm` | binary subpackage | `mingw-gettext` | [specs/m/mingw-gettext/mingw-gettext.spec](specs/m/mingw-gettext/mingw-gettext.spec) | `%package -n mingw64-gettext-static`. Listed under both `sdk/x86_64` and `sdk/aarch64` (same `noarch` RPM). |
| `mingw64-libxml2-static-2.12.10-2.azl4~20260420.noarch.rpm` | binary subpackage | `mingw-libxml2` | [specs/m/mingw-libxml2/mingw-libxml2.spec](specs/m/mingw-libxml2/mingw-libxml2.spec) | `%package -n mingw64-libxml2-static`; `Version: 2.12.10`. Listed under both `sdk/x86_64` and `sdk/aarch64` (same `noarch` RPM). |
| `mozjs128-128.11.0-1.azl4~20260420.src.rpm` | SRPM | `mozjs128` | [specs/m/mozjs128/mozjs128.spec](specs/m/mozjs128/mozjs128.spec) | Direct (Version 128.11.0). |
| `openfec-debuginfo-1.4.2.6-7.azl4~20260420.aarch64.rpm` | auto-generated debuginfo | `openfec` | [specs/o/openfec/openfec.spec](specs/o/openfec/openfec.spec) | aarch64 build. Standard `*-debuginfo` produced by rpmbuild from the `openfec` SRPM. |
| `openfec-debuginfo-1.4.2.6-7.azl4~20260420.x86_64.rpm` | auto-generated debuginfo | `openfec` | [specs/o/openfec/openfec.spec](specs/o/openfec/openfec.spec) | x86_64 build. Standard `*-debuginfo` produced by rpmbuild from the `openfec` SRPM. |
| `perl-Module-Signature-0.93-2.azl4~20260420.noarch.rpm` | binary (`noarch`) | `perl-Module-Signature` | [specs/p/perl-Module-Signature/perl-Module-Signature.spec](specs/p/perl-Module-Signature/perl-Module-Signature.spec) | Listed under both `base/x86_64` and `base/aarch64` (same `noarch` RPM). |
| `perl-Module-Signature-0.93-2.azl4~20260420.src.rpm` | SRPM | `perl-Module-Signature` | [specs/p/perl-Module-Signature/perl-Module-Signature.spec](specs/p/perl-Module-Signature/perl-Module-Signature.spec) | SRPM that produces the `noarch` binary above. |
| `perl-Test-Signature-1.11-35.azl4~20260420.noarch.rpm` | binary (`noarch`) | `perl-Test-Signature` | [specs/p/perl-Test-Signature/perl-Test-Signature.spec](specs/p/perl-Test-Signature/perl-Test-Signature.spec) | Listed under both `sdk/x86_64` and `sdk/aarch64` (same `noarch` RPM). |
| `perl-Test-Signature-1.11-35.azl4~20260420.src.rpm` | SRPM | `perl-Test-Signature` | [specs/p/perl-Test-Signature/perl-Test-Signature.spec](specs/p/perl-Test-Signature/perl-Test-Signature.spec) | SRPM that produces the `noarch` binary above. |
| `python-impacket-0.12.0-1.azl4~20260420.src.rpm` | SRPM | `python-impacket` | [specs/p/python-impacket/python-impacket.spec](specs/p/python-impacket/python-impacket.spec) | Direct (Version 0.12.0). |
| `python3-impacket-0.12.0-1.azl4~20260420.noarch.rpm` | binary subpackage | `python-impacket` | [specs/p/python-impacket/python-impacket.spec](specs/p/python-impacket/python-impacket.spec) | Generated as `python3-impacket` from the `python-impacket` SRPM. Listed under both `sdk/x86_64` and `sdk/aarch64` (same `noarch` RPM). |
| `qemu-tests-10.1.4-1.azl4~20260420.aarch64.rpm` | binary subpackage | `qemu` | [specs/q/qemu/qemu.spec](specs/q/qemu/qemu.spec) | aarch64 build of the `qemu-tests` subpackage; `Version: 10.1.4`. |
| `qemu-tests-10.1.4-1.azl4~20260420.x86_64.rpm` | binary subpackage | `qemu` | [specs/q/qemu/qemu.spec](specs/q/qemu/qemu.spec) | x86_64 build of `%package tests`; `Version: 10.1.4`. Likely scanner trigger: the qemu test suite ships intentionally-malformed binaries / firmware blobs used as fuzzer fixtures. |
| `qt6-qtwebengine-6.10.2-1.azl4~20260420.src.rpm` | SRPM | `qt6-qtwebengine` | [specs/q/qt6-qtwebengine/qt6-qtwebengine.spec](specs/q/qt6-qtwebengine/qt6-qtwebengine.spec) | Direct (Version 6.10.2). Note: bundles a Chromium tree internally — likely the same scanner trigger as `chromium`. |
| `rubygem-pdf-reader-2.4.2-10.azl4~20260420.src.rpm` | SRPM | `rubygem-pdf-reader` | [specs/r/rubygem-pdf-reader/rubygem-pdf-reader.spec](specs/r/rubygem-pdf-reader/rubygem-pdf-reader.spec) | Direct. |
| `samba-winexe-4.23.5-1.azl4~20260420.aarch64.rpm` | binary subpackage | `samba` | [specs/s/samba/samba.spec](specs/s/samba/samba.spec) | aarch64 build of `samba-winexe`; same spec as the x86_64 entry. |
| `samba-winexe-4.23.5-1.azl4~20260420.x86_64.rpm` | binary subpackage | `samba` | [specs/s/samba/samba.spec](specs/s/samba/samba.spec) | x86_64 build of `samba-winexe`. `%package winexe` gated by `%bcond winexe 1`; `%global samba_version 4.23.5` matches. |
| `star-1.6-18.azl4~20260420.src.rpm` | SRPM | `star` | [specs/s/star/star.spec](specs/s/star/star.spec) | Direct. |
| `stress-ng-0.20.01-1.azl4~20260420.src.rpm` | SRPM | `stress-ng` | [specs/s/stress-ng/stress-ng.spec](specs/s/stress-ng/stress-ng.spec) | Direct (Version 0.20.01). |
| `texlive-2023-80.azl4~20260420.src.rpm` | SRPM | `texlive` | [specs/t/texlive/texlive.spec](specs/t/texlive/texlive.spec) | `%global tl_version 2023`; `Version: %{tl_version}` → "2023". |
| `yara-4.5.4-1.azl4~20260420.src.rpm` | SRPM | `yara` | [specs/y/yara/yara.spec](specs/y/yara/yara.spec) | Direct (Version 4.5.4). Likely scanner self-recognition: YARA ships malware-rule fixtures in its test corpus. |
| `chromium-145.0.7632.109-1.azl4~20260420.src.rpm` | SRPM | **(none — not in this repo)** | — | **Cannot map.** No `chromium` component or spec exists in this repo. The comment in [base/comps/rubygem-railties/rubygem-railties.comp.toml](base/comps/rubygem-railties/rubygem-railties.comp.toml) explicitly states: *"Chromium/chromedriver are not available in Azure Linux"*. The SRPM in the AZL4 Alpha2 repo therefore must originate from an upstream / external source (e.g. a Fedora rebuild ingested into the publish flow), not from this `azurelinux` repo. **This needs follow-up with the publishing pipeline owners** to confirm where this SRPM is produced. Sorted to the end of the table since there is no component name to alphabetise on. |

---

## Summary by component

The **31 unique failing RPMs** (collapsing duplicates across architectures and
between `base/*` & `base/srpms`) map to **29 distinct components** in this
repo, plus **1 RPM (`chromium`) that does not map to any component** here.

Components affected (sorted):

1. `apache-commons-compress`
2. `espeak-ng`
3. `exfatprogs`
4. `firefox`
5. `gdal`
6. `ghc`
7. `java-25-openjdk`
8. `java-25-openjdk-portable`
9. `kf6-karchive`
10. `libabigail`
11. `libkml`
12. `llvm`
13. `llvm20`
14. `mathjax`
15. `mingw-gettext`
16. `mingw-libxml2`
17. `mozjs128`
18. `openfec`
19. `perl-Module-Signature`
20. `perl-Test-Signature`
21. `python-impacket`
22. `qemu`
23. `qt6-qtwebengine`
24. `rubygem-pdf-reader`
25. `samba`
26. `star`
27. `stress-ng`
28. `texlive`
29. `yara`

(29 entries — `java-25-openjdk` and `java-25-openjdk-portable` are listed
separately because they are independent SRPMs; `python-impacket` covers both
the SRPM and the `python3-impacket` binary subpackage; `llvm` and `llvm20` are
separate component SRPMs.)

## Unmapped RPMs

| RPM | Reason |
|---|---|
| `chromium-145.0.7632.109-1.azl4~20260420.src.rpm` | No `chromium` spec or component exists in this repository (`grep` over `base/comps/**/*.toml` and `specs/**/*.spec` returns nothing). The repo explicitly notes Chromium is not packaged in Azure Linux (see [base/comps/rubygem-railties/rubygem-railties.comp.toml](base/comps/rubygem-railties/rubygem-railties.comp.toml)). The SRPM listed in the AZL4 Alpha2 publishing flow must therefore come from an external source (e.g. an upstream Fedora rebuild that is ingested into the AZL4 publishing pipeline outside of this repo). Follow up with the publishing pipeline owners to identify the source repository. |

## Notes / observations for triage

- Many of the failures are highly plausible **false positives from the malware
  scanner**:
  - `yara` ships its own test corpus of malware-detection fixtures.
  - `qemu-tests` ships intentionally-malformed firmware/binaries used as
    fuzzer fixtures.
  - `qt6-qtwebengine` and `firefox` bundle a full Chromium tree internally and
    contain large blobs of obfuscated/optimised JS that frequently trip
    heuristic engines (this is consistent with `chromium` itself failing).
  - `mozjs128` (the SpiderMonkey JavaScript engine used by Firefox) — same
    family of triggers as Firefox/Chromium.
  - `perl-Module-Signature` / `perl-Test-Signature` — packages whose entire
    purpose is to verify cryptographic signatures; their test data may include
    deliberately-malformed signed payloads.
  - `samba-winexe` ships a precompiled Windows PE binary
    (`/usr/bin/winexe.exe`) used to launch commands on remote Windows hosts
    via SMB — this is exactly the kind of artefact AV engines flag as a
    hack-tool / "remote command execution utility" (see also `python-impacket`
    / `python3-impacket`, which is the canonical Python SMB/MSRPC toolkit
    used by red-team tools).
  - `*-static` packages (`llvm-static`, `llvm20-static`,
    `mingw64-gettext-static`, `mingw64-libxml2-static`,
    `java-25-*-static-libs-slowdebug`, `ghc-ghc-prof`) ship large static
    archives whose contents heuristic scanners often misclassify.
  - `mathjax` is JavaScript bundles; `texlive`, `kf6-karchive`,
    `apache-commons-compress`, `rubygem-pdf-reader`, `libkml`, `gdal`,
    `libabigail`, `espeak-ng`, `exfatprogs`, `star`, `stress-ng` — these are
    less obvious; would need the actual scanner's `virus_to_srpm_matches`
    spreadsheet (linked in the source e-mail) to triage individually.

- **Next step**: cross-reference this list against the
  `virus_to_srpm_matches-partial.xlsx` attachment referenced at the bottom of
  the source e-mail to get the specific virus-name → file-path matches per
  SRPM, then decide for each whether to (a) request a scanner allow-list /
  exception, (b) strip the offending fixture/blob via an overlay, or (c)
  exclude the affected sub-package from publishing.
