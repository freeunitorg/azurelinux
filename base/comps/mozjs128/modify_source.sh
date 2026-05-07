#!/usr/bin/env bash
#
# mozjs128 -- strip Firefox-only subtrees from upstream tarball.
#
# Background
# ----------
# `mozjs128` builds the SpiderMonkey JavaScript engine from the
# upstream Firefox ESR source tarball.  The full Firefox tree
# carries assorted artefacts that the automated malware scan in our
# package signing pipeline rejects -- vendored Windows PE binaries
# (NSIS plugin DLLs, 7-Zip stubs, telemetry/mozapps/mozbase test
# fixtures, signed `msvcp140.dll`), oss-fuzz seed corpora,
# deliberately-malformed media/image/font crash-test inputs,
# encrypted ZIP test fixtures, and similar test data -- none of
# which `mozjs128` ever compiles or installs:
#
#   * `%prep` already does `rm -rf modules/zlib`,
#     `rm -rf js/src/devtools/automation/variants/`,
#     `rm -rf js/src/octane/`, `rm -rf js/src/ctypes/libffi/` -- but
#     the malware scanner inspects the SRPM blob, which contains
#     Source0 verbatim, so `%prep`-time deletions are too late.
#   * `%configure` runs from `js/src/`; `%make_build` and
#     `%make_install` run from `js/src/`. Nothing outside the keep
#     list below is referenced by mozjs128's build.
#
# This script downloads the upstream Firefox ESR source tarball,
# extracts it, deletes everything outside the SpiderMonkey-build
# keep list, and repacks the result deterministically as a .tar.xz
# (matching the upstream extension so `mozjs128.spec`'s Source0
# line `Source0: ...firefox-%{version}esr.source.tar.xz` does not
# need to change) that becomes the new Source0 for `mozjs128`.
#
# Why we did NOT remove `mozjs128` entirely
# -----------------------------------------
# A simpler "remove the component" path was considered and
# rejected after a dependency-impact scan turned up reverse
# dependencies that have to keep building:
#
#   * `specs/c/cjs/cjs.spec` L42:
#       BuildRequires: pkgconfig(mozjs-128) >= %{mozjs128_version}
#     L58:
#       Requires: mozjs128%{?_isa} >= %{mozjs128_version}
#   * `specs/c/cinnamon/cinnamon.spec` L52:
#       BuildRequires: pkgconfig(cjs-1.0) >= %{cjs_version}
#     L95:
#       Requires: cjs%{?_isa} >= %{cjs_version}
#   * `base/comps/components.toml` keeps `[components.cjs]` and
#     `[components.cinnamon]` plus seven `cinnamon-*` packages.
#
# Removing `mozjs128` would break the `cjs` build and the entire
# Cinnamon desktop environment -- which we want to keep. The
# Source0 strip preserves the SpiderMonkey build artefacts
# `cjs` and Cinnamon need (`libmozjs-128.so*`, `mozjs-128/`
# headers, `mozjs-128.pc`) while dropping the Firefox subtrees the
# malware scanner flags.
#
# Reproducibility notes
# ---------------------
# - `tar --sort=name --mtime=` flags produce a byte-deterministic
#   output, so re-running on the same upstream tarball must yield
#   the same SHA512.
# - `xz -T1 -9e --no-adjust` is used (single-threaded, max
#   compression, no preset adjust): single-threaded xz is
#   byte-deterministic for the same input, while multi-threaded
#   `xz -T0` is NOT (block boundaries vary by thread count).
#
# Output location
# ---------------
# The script writes its outputs to
# `base/build/work/scratch/mozjs128/` (resolved relative to the
# repository root). This path is covered by the repository's
# top-level `.gitignore` via `build/`, so no component-level
# `.gitignore` is needed and no script artefact can be
# accidentally committed.
#
# !!! THIS SCRIPT MUST BE RUN BY THE MAINTAINER TO POPULATE THE
# !!! `source-files.hash` IN `mozjs128.comp.toml`.  The committed
# !!! comp.toml uses a placeholder SHA512 marked TBD until that's
# !!! done.

set -euo pipefail

VERSION="128.11.0"
ORIGINAL_NAME="firefox-${VERSION}esr.source.tar.xz"
EXTRACTED_DIRNAME="firefox-${VERSION}"
MODIFIED_NAME="firefox-${VERSION}esr-azl-mozjs-stripped.tar.xz"
UPSTREAM_URL="https://ftp.mozilla.org/pub/firefox/releases/${VERSION}esr/source/${ORIGINAL_NAME}"

# Populated from upstream Mozilla SHA512SUMS:
#   https://ftp.mozilla.org/pub/firefox/releases/128.11.0esr/SHA512SUMS
ORIGINAL_SHA512="80af64c1dce6d7a25111480567a3251cc2d1edce00acc4d85bbaa44590f5bbf4c0716f9490c3ab8ef1e6fc2bbabb2379029c2dee51ce477933c7a5935092d279"

# Paths to keep, relative to the extracted firefox-${VERSION} root.
# Anything not under these prefixes is deleted before the repack.
#
# Derived from `mozjs128.spec`:
#   - `%autosetup -n firefox-%{version}` => extract dir is the root
#   - `cp LICENSE js/src/`               => need top-level LICENSE
#   - `pushd js/src/` for %configure / %make_build / %make_install
#   - `sed -i 's/icu-i18n/icu-uc &/' js/moz.configure` => need js/
#   - `export AC_MACRODIR=./build/autoconf/`            => need build/
#   - SpiderMonkey configure pulls in mfbt/, memory/, mozglue/,
#     python/mozbuild/ (Mozilla Build System core)
#   - top-level Cargo.{toml,lock} for the workspace + js/src/Cargo.toml
#   - top-level moz.configure references js/moz.configure
#   - `third_party/` for vendored Rust crates that the SpiderMonkey
#     cargo build links against, AND for `%prep`'s explicit
#     `chmod -x third_party/rust/bumpalo/src/lib.rs`
#     (mozjs128.spec line 141 -- would fail under set -e if missing).
KEEP_PATHS=(
    "LICENSE"
    "Cargo.toml"
    "Cargo.lock"
    "moz.configure"
    "build/"
    "config/"
    "js/"
    "mfbt/"
    "memory/"
    "mozglue/"
    "python/mozbuild/"
    "third_party/"
)

# Within `js/`, also strip the fuzzer corpora the malware scanner
# repeatedly flags:
JS_STRIP_PATHS=(
    "${EXTRACTED_DIRNAME}/js/src/fuzz-tests/"
    "${EXTRACTED_DIRNAME}/js/src/devtools/automation/variants/"
    "${EXTRACTED_DIRNAME}/js/src/octane/"
    "${EXTRACTED_DIRNAME}/js/src/ctypes/libffi/"
)

if [[ "${ORIGINAL_SHA512}" == "TBD" ]]; then
    cat >&2 <<EOF
ERROR: ORIGINAL_SHA512 is set to "TBD" in this script.

To populate it:
  1. Visit https://ftp.mozilla.org/pub/firefox/releases/${VERSION}esr/SHA512SUMS
  2. Find the line for ${ORIGINAL_NAME}
  3. Edit this script and replace the ORIGINAL_SHA512="TBD" line with
     the real value.

This guard exists because mozjs128's upstream tarball is ~500 MB; we
refuse to download without an integrity check on the way in.
EOF
    exit 1
fi

# Resolve the script's own directory, then walk up to the repo root
# so the work directory lands at base/build/work/scratch/mozjs128/
# no matter where the script is invoked from.  Layout:
#   <repo-root>/base/comps/mozjs128/modify_source.sh   <- this script
#   <repo-root>/base/build/work/scratch/mozjs128/      <- WORKDIR
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
WORKDIR="${REPO_ROOT}/base/build/work/scratch/mozjs128"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

echo "[1/6] Downloading ${ORIGINAL_NAME} into ${WORKDIR}"
if [[ ! -f "${ORIGINAL_NAME}" ]]; then
    curl -fsSL --retry 3 -o "${ORIGINAL_NAME}" "${UPSTREAM_URL}"
fi

echo "[2/6] Verifying original SHA512"
COMPUTED_ORIGINAL_SHA512=$(sha512sum "${ORIGINAL_NAME}" | awk '{print $1}')
if [[ "${COMPUTED_ORIGINAL_SHA512}" != "${ORIGINAL_SHA512}" ]]; then
    echo "ERROR: upstream SHA512 mismatch" >&2
    echo "  expected: ${ORIGINAL_SHA512}" >&2
    echo "  computed: ${COMPUTED_ORIGINAL_SHA512}" >&2
    exit 1
fi

echo "[3/6] Extracting"
rm -rf "${EXTRACTED_DIRNAME}"
tar -xf "${ORIGINAL_NAME}"

echo "[4/6] Stripping non-keep top-level paths"
# Build a `find` exclusion expression for the keep list, then delete
# everything else inside the extracted dir.  Nested keep paths are
# handled by walking the top level only.
cd "${EXTRACTED_DIRNAME}"
for entry in $(ls -A); do
    keep=0
    for k in "${KEEP_PATHS[@]}"; do
        kclean="${k%/}"
        if [[ "${entry}" == "${kclean}" ]]; then
            keep=1
            break
        fi
    done
    if [[ "${keep}" -eq 0 ]]; then
        rm -rf "${entry}"
    fi
done
cd ..

echo "[4b/6] Stripping known-flagged subdirs inside js/"
for p in "${JS_STRIP_PATHS[@]}"; do
    # Re-prefixed because we're back at WORKDIR.
    rel="${p#${EXTRACTED_DIRNAME}/}"
    if [[ -e "${EXTRACTED_DIRNAME}/${rel}" ]]; then
        rm -rfv "${EXTRACTED_DIRNAME}/${rel}"
    fi
done

echo "[5/6] Repacking deterministically as ${MODIFIED_NAME}"
# --sort=name        : deterministic file ordering
# --mtime            : pin mtime to a fixed epoch so the output is reproducible
# --owner=0 --group=0 --numeric-owner : strip uid/gid/uname/gname
# xz -T1             : single-threaded xz so block boundaries are
#                      deterministic across runs (-T0 is NOT)
# xz -9e             : max compression / extreme mode (smaller output)
rm -f "${MODIFIED_NAME}"
tar --sort=name \
    --mtime='2024-01-01 00:00:00 UTC' \
    --owner=0 --group=0 --numeric-owner \
    -cf - "${EXTRACTED_DIRNAME}" | xz -T1 -9e > "${MODIFIED_NAME}"

MODIFIED_SHA512=$(sha512sum "${MODIFIED_NAME}" | awk '{print $1}')
echo "${MODIFIED_SHA512}  ${MODIFIED_NAME}" > "${MODIFIED_NAME}.sha512"

echo
echo "================================================================"
echo "DONE"
echo "  modified tarball: ${WORKDIR}/${MODIFIED_NAME}"
echo "  SHA512:           ${MODIFIED_SHA512}"
echo "================================================================"
echo
echo "Next steps:"
echo "  1. Update base/comps/mozjs128/mozjs128.comp.toml -- replace the"
echo "     TBD-SHA512-PLACEHOLDER value (which appears in BOTH the"
echo "     source-files.hash field AND the URI's \$hash path segment)"
echo "     with: ${MODIFIED_SHA512}"
echo "  2. Make sure you are logged in to Azure (one-time per shell):"
echo "       az login"
echo "  3. Upload the modified tarball with this ready-to-paste command"
echo "     (uploads to the lookaside 'repo' container under the"
echo "     'pkgs_modified/' prefix at the exact path the comp.toml"
echo "     source-files.origin.uri above expects):"
echo
echo "       az storage blob upload \\"
echo "           --auth-mode login \\"
echo "           --account-name azltempstaginglookaside \\"
echo "           --container-name repo \\"
echo "           --name \"pkgs_modified/mozjs128/firefox-128.11.0esr.source.tar.xz/sha512/${MODIFIED_SHA512}/firefox-128.11.0esr.source.tar.xz\" \\"
echo "           --file \"${WORKDIR}/${MODIFIED_NAME}\""
echo
echo "  4. The mozjs128.spec Source0 line points to a .tar.xz with the"
echo "     SAME upstream filename, so no spec edit is needed."
