#!/usr/bin/env bash
#
# yara — strip benign-but-scanner-tripping fixture from upstream tarball.
#
# Background
# ----------
# An automated malware scan in the package signing pipeline rejects
# `tests/oss-fuzz/dotnet_fuzzer_corpus/obfuscated` inside the upstream
# `yara-4.5.4.tar.gz` tarball.  The file is a deliberately obfuscated
# .NET binary used as an oss-fuzz seed-corpus input for YARA's `.NET`
# parser fuzzer; it is benign but matches generic .NET-obfuscator
# heuristics by design.
#
# The `*_fuzzer.cc` oss-fuzz harnesses (and their `*_fuzzer_corpus/`
# directories) are NOT referenced from upstream's `Makefile.am`, so the
# autotools `make check` driver does not exercise them.  Removing
# `tests/oss-fuzz/dotnet_fuzzer_corpus/obfuscated` (and, optionally,
# the rest of the dotnet fuzzer corpus) does not affect the Azure Linux
# build or `%check`.
#
# This script repacks the upstream tarball with the offending file
# stripped, then prints the SHA512 of the modified artefact for use in
# `base/comps/yara/yara.comp.toml`'s `source-files` block.  The
# modified tarball must be uploaded to the Azure Linux modified-source
# blob storage; its blob URL becomes the `source-files.origin.uri` in
# the comp TOML.
#
# Reproducibility notes
# ---------------------
# - The script uses `tar --sort=name --mtime=` flags to produce a
#   byte-deterministic output, so re-running on the same upstream
#   tarball must always yield the same SHA512.
# - `gzip -n` strips mtime/filename metadata from the gzip header for
#   the same reason.
#
# Output location
# ---------------
# The script writes its outputs to `base/build/work/scratch/yara/`
# (resolved relative to the repository root).  This path is covered by
# the repository's top-level `.gitignore` via `build/`, so no
# component-level `.gitignore` is needed and no script artefact can be
# accidentally committed.
#
# Usage:
#   bash modify_source.sh
#
# Outputs (under base/build/work/scratch/yara/):
#   yara-4.5.4-azl-stripped.tar.gz
#   yara-4.5.4-azl-stripped.tar.gz.sha512
#
# After running:
#   1. Upload `yara-4.5.4-azl-stripped.tar.gz` as the blob payload at
#      the lookaside URL pattern (modified container) for filename
#      `yara-4.5.4.tar.gz`.  The exact URL is printed by this script.
#   2. The `hash` and `origin.uri` fields in
#      `base/comps/yara/yara.comp.toml` are already populated for the
#      SHA512 produced by this script; if your run produces a
#      different SHA512, update both the `source-files.hash` value and
#      the URI's `$hash` path segment to the new value.

set -euo pipefail

UPSTREAM_URL="https://github.com/VirusTotal/yara/archive/v4.5.4.tar.gz"
ORIGINAL_NAME="yara-4.5.4.tar.gz"
ORIGINAL_SHA512="b1da40636f9e55bb07cc911479e6dfa8dc7a4fa3f6b9f10b9f669d741d7af51a1d31e044f9842ec3ab9c6ac9788fbdb89a1686c9e3f22f68d1f9e5fb3db22167"
MODIFIED_NAME="yara-4.5.4-azl-stripped.tar.gz"
EXTRACTED_DIRNAME="yara-4.5.4"

# Files to remove from the upstream tarball.  Keep this list explicit and
# short so the rationale is always auditable.
declare -a STRIP_PATHS=(
    "${EXTRACTED_DIRNAME}/tests/oss-fuzz/dotnet_fuzzer_corpus/obfuscated"
)

# Resolve the script's own directory, then walk up to the repo root so
# the work directory lands at base/build/work/scratch/yara/ no matter
# where the script is invoked from.  Layout:
#   <repo-root>/base/comps/yara/modify_source.sh           <- this script
#   <repo-root>/base/build/work/scratch/yara/              <- WORKDIR
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
WORKDIR="${REPO_ROOT}/base/build/work/scratch/yara"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

echo "[1/5] Downloading ${ORIGINAL_NAME} from upstream into ${WORKDIR}"
curl -fsSL --retry 3 -o "${ORIGINAL_NAME}" "${UPSTREAM_URL}"

echo "[2/5] Verifying original SHA512"
COMPUTED_ORIGINAL_SHA512=$(sha512sum "${ORIGINAL_NAME}" | awk '{print $1}')
if [[ "${COMPUTED_ORIGINAL_SHA512}" != "${ORIGINAL_SHA512}" ]]; then
    echo "ERROR: upstream SHA512 mismatch" >&2
    echo "  expected: ${ORIGINAL_SHA512}" >&2
    echo "  computed: ${COMPUTED_ORIGINAL_SHA512}" >&2
    exit 1
fi

echo "[3/5] Extracting"
rm -rf "${EXTRACTED_DIRNAME}"
tar -xzf "${ORIGINAL_NAME}"

echo "[4/5] Stripping flagged paths"
for p in "${STRIP_PATHS[@]}"; do
    if [[ ! -e "${p}" ]]; then
        echo "ERROR: expected path not present in upstream: ${p}" >&2
        exit 1
    fi
    rm -v "${p}"
done

echo "[5/5] Repacking deterministically as ${MODIFIED_NAME}"
# --sort=name        : deterministic file ordering
# --mtime            : pin mtime to a fixed epoch so the output is reproducible
# --owner=0 --group=0 --numeric-owner : strip uid/gid/uname/gname
# gzip -n            : do not store the mtime/filename in the gzip header
rm -f "${MODIFIED_NAME}"
tar --sort=name \
    --mtime='2024-01-01 00:00:00 UTC' \
    --owner=0 --group=0 --numeric-owner \
    -cf - "${EXTRACTED_DIRNAME}" | gzip -n -9 > "${MODIFIED_NAME}"

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
echo "  1. Make sure you are logged in to Azure (one-time per shell):"
echo "       az login"
echo "  2. Upload the modified tarball with this ready-to-paste command"
echo "     (uploads to the lookaside 'repo' container under the"
echo "     'pkgs_modified/' prefix at the exact path"
echo "     base/comps/yara/yara.comp.toml's source-files.origin.uri expects):"
echo
echo "       az storage blob upload \\"
echo "           --auth-mode login \\"
echo "           --account-name azltempstaginglookaside \\"
echo "           --container-name repo \\"
echo "           --name \"pkgs_modified/yara/yara-4.5.4.tar.gz/sha512/${MODIFIED_SHA512}/yara-4.5.4.tar.gz\" \\"
echo "           --file \"${WORKDIR}/${MODIFIED_NAME}\""
echo
echo "  3. The hash + URI in base/comps/yara/yara.comp.toml are"
echo "     already populated for SHA512 ${MODIFIED_SHA512:0:16}...; if the"
echo "     SHA512 above does NOT match, update both the source-files.hash"
echo "     value, the URI's \$hash path segment, and the --name argument"
echo "     in the upload command above to the new value."
