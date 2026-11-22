#!/usr/bin/env bash
# Compress, extract, or remove files in the current working directory.
set -u -o pipefail
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
    cat <<'USAGE'
Usage:
  bash file-maintenance.sh [--dry-run] compress --file FILE [OPTIONS]
  bash file-maintenance.sh [--dry-run] compress --extension EXT [OPTIONS]
  bash file-maintenance.sh [--dry-run] extract --extension 7z|zip [--extract-to-folder]
  bash file-maintenance.sh [--dry-run] delete PATTERN [PATTERN ...]

Compression defaults: --level 2 --threads 2 --method LZMA2
                      --dictionary 16m --solid on

Compression by extension and deletion recurse from the working directory.
Searches skip names beginning with a dot. Extraction considers archives
in the working directory only. Use
--extract-to-folder to extract each archive into a folder named after it.
Quote deletion globs, such as '*.tmp', to match names at every depth.

Compression creates a sibling .7z and deletes the input after verification.
Extraction renames incoming files on collision and deletes the archive only
on success. A pre-existing compression destination is an error.
Ctrl+C stops the batch.
Requires Bash, GNU find/coreutils, and 7-Zip for compress and extract.
USAGE
}

fail() {
    printf '%s\n' "$*" >&2
    exit 2
}

find_7zip() {
    local program
    for program in 7z 7zz 7za 7z.exe; do
        if command -v "$program" >/dev/null 2>&1; then
            seven_zip=$program
            return
        fi
    done
    fail '7-Zip is required. Add 7z or 7zz to PATH.'
}

run_7zip() {
    local status=0
    "$seven_zip" "$@" || status=$?
    # 7-Zip returns 255 when the user cancels. A Windows console abort can
    # also surface as the low byte of STATUS_CONTROL_C_EXIT in Git Bash.
    case $status in
        255) return 130 ;;
        58)
            if [[ $OSTYPE == msys* || $OSTYPE == cygwin* ]]; then return 130; fi
            ;;
    esac
    return "$status"
}

verify_compression() {
    local archive=$1 original=$2
    local -a statuses
    run_7zip x -so -bd -- "$archive" | cmp - "$original"
    statuses=("${PIPESTATUS[@]}")
    if (( statuses[0] == 130 || statuses[1] == 130 )); then return 130; fi
    if (( statuses[0] == 143 || statuses[1] == 143 )); then return 143; fi
    (( statuses[0] == 0 && statuses[1] == 0 ))
}

report_failure() {
    local status=$1 message=$2
    case $status in
        130|143)
            printf 'Batch interrupted.\n' >&2
            return "$status"
            ;;
    esac
    printf '%s\n' "$message" >&2
    return 1
}

compress_file() (
    local path=$1 directory=. name stem archive scratch temporary status=0
    trap 'exit 130' INT
    trap 'exit 143' TERM
    name=${path##*/}
    if [[ $path == */* ]]; then directory=${path%/*}; fi
    if [[ ! -f $path || -L $path ]]; then
        printf 'Expected a regular file: %s\n' "$path" >&2
        return 1
    fi
    stem=${name%.*}
    archive=./${stem:-$name}.7z
    cd -- "${directory:-/}" || return 1
    if [[ -e $archive || -L $archive ]]; then
        printf 'Archive already exists for %s: %s\n' "$path" "${archive#./}" >&2
        return 1
    fi
    if (( dry_run )); then
        printf 'Would compress and remove: %s\n' "$path"
        return
    fi

    scratch=$(mktemp -d ./.compress-7z.XXXXXXXX) || return 1
    temporary=$scratch/archive.7z
    trap 'rm -f -- "$temporary"; rmdir -- "$scratch"' EXIT
    run_7zip a -bd -bso0 -mx="$level" -mmt="$threads" -m0="$method" \
        -md="$dictionary" -ms="$solid" -spd -- "$temporary" "./$name" &&
        verify_compression "$temporary" "./$name" || status=$?
    if (( status != 0 )); then
        report_failure "$status" "Compression verification failed for $path"
        return "$?"
    fi
    if ! mv -nT -- "$temporary" "$archive" || [[ -e $temporary ]]; then
        printf 'Could not publish archive for %s\n' "$path" >&2
        return 1
    fi
    rm -- "./$name" || return 1
    printf 'Compressed: %s -> %s\n' "$path" "${archive#./}"
)

extract_archive() {
    local archive=$1 target=. status=0
    if (( extract_to_folder )); then target=${archive%.*}; fi
    if (( dry_run )); then
        printf 'Would extract and remove: %s -> %s\n' "$archive" "$target"
        return
    fi
    if [[ -L $target ]]; then
        printf 'Extraction destination is a symbolic link: %s\n' "$target" >&2
        return 1
    fi
    run_7zip t -bd -bso0 -- "$archive" &&
        run_7zip x -bd -bso0 -y -aou "-o$target" -- "$archive" || status=$?
    if (( status != 0 )); then
        report_failure "$status" "Extraction failed. Archive retained: $archive"
        return "$?"
    fi
    rm -- "$archive" || return 1
    printf 'Extracted: %s -> %s\n' "$archive" "$target"
}

remove_file() {
    if (( dry_run )); then
        printf 'Would delete: %s\n' "$1"
    else
        rm -- "$1" || return 1
        printf 'Deleted: %s\n' "$1"
    fi
}

process_paths() {
    local action=$1 path status=0 result
    trap 'exit 130' INT
    trap 'exit 143' TERM
    while IFS= read -r -d '' path; do
        result=0
        "$action" "$path" || result=$?
        case $result in
            0) ;;
            130|143) return "$result" ;;
            *) status=1 ;;
        esac
    done
    return "$status"
}

dry_run=0
if [[ ${1-} == --dry-run ]]; then
    dry_run=1
    shift
fi

case ${1-} in
    -h|--help) usage; exit 0 ;;
    compress|extract|delete) operation=$1; shift ;;
    *) usage >&2; exit 2 ;;
esac

if [[ $operation == delete ]]; then
    if [[ ${1-} == -- ]]; then shift; fi
    (( $# )) || fail 'Supply at least one file name or quoted pattern.'
    matches=()
    for pattern in "$@"; do
        [[ -n $pattern && $pattern != */* ]] || fail 'Use file names or patterns, without directory paths.'
        if (( ${#matches[@]} )); then matches+=(-o); fi
        matches+=(-iname "$pattern")
    done
    find . -mindepth 1 -name '.*' -prune -o -type f \( "${matches[@]}" \) -print0 |
        process_paths remove_file
    exit "$?"
fi

file=
extension=
level=2
threads=2
method=LZMA2
dictionary=16m
solid=on
extract_to_folder=0
while (( $# )); do
    if [[ $1 == --extract-to-folder && $operation == extract ]]; then
        extract_to_folder=1
        shift
        continue
    fi
    (( $# >= 2 )) && [[ -n $2 && $2 != --* ]] || fail "Missing value or unknown option: $1"
    case "$operation:$1" in
        *:--extension) extension=${2#.} ;;
        compress:--file) file=$2 ;;
        compress:--level) level=$2 ;;
        compress:--threads) threads=$2 ;;
        compress:--method) method=$2 ;;
        compress:--dictionary) dictionary=$2 ;;
        compress:--solid) solid=$2 ;;
        *) fail "Unknown option for $operation: $1" ;;
    esac
    shift 2
done

if [[ $operation == extract ]]; then
    case $extension in
        7[zZ]|[zZ][iI][pP]) ;;
        *) fail 'Specify --extension 7z or --extension zip.' ;;
    esac
    if (( ! dry_run )); then find_7zip; fi
    find . -maxdepth 1 -type f ! -name '.*' -iname "*.$extension" -print0 |
        process_paths extract_archive
    exit "$?"
fi

if [[ -n $file && -n $extension || -z $file && -z $extension ]]; then
    fail 'Specify exactly one of --file or --extension.'
fi
[[ -z $extension || $extension =~ ^[[:alnum:]_+-]+$ ]] || fail 'Specify a literal file extension.'
[[ $level =~ ^[0-9]$ && $threads =~ ^[1-9][0-9]*$ ]] ||
    fail 'Compression level must be 0–9 and the number of threads must be positive.'
if (( ! dry_run )); then find_7zip; fi
if [[ -n $file ]]; then
    compress_file "$file"
else
    find . -mindepth 1 -name '.*' -prune -o -type f -iname "*.$extension" -print0 |
        process_paths compress_file
fi
