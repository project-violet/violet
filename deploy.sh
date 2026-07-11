#!/usr/bin/env sh
set -eu

install_dir=${VIOLET_INSTALL_DIR:-"$PWD/.violet"}
compose_file=${VIOLET_COMPOSE_FILE:-"$install_dir/docker-compose.yml"}
compose_url=${VIOLET_COMPOSE_URL:-"https://raw.githubusercontent.com/project-violet/violet/main/docker-compose.release.yml"}
data_root=${VIOLET_DATA_ROOT:-"$install_dir/data"}

if ! command -v docker >/dev/null 2>&1; then
    printf '%s\n' 'Docker is required but was not found in PATH.' >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    printf '%s\n' 'Docker Compose v2 is required (docker compose).' >&2
    exit 1
fi

if [ -z "${VIOLET_COMPOSE_FILE:-}" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        printf '%s\n' 'curl is required to download the release Compose file.' >&2
        exit 1
    fi
    mkdir -p "$install_dir"
    compose_tmp="$compose_file.tmp"
    printf 'Downloading release Compose file from %s...\n' "$compose_url"
    curl -fsSL "$compose_url" -o "$compose_tmp"
    mv "$compose_tmp" "$compose_file"
fi

if [ ! -f "$compose_file" ]; then
    printf 'Compose file not found: %s\n' "$compose_file" >&2
    exit 1
fi

missing=0
for data_file in data.db user.db merged-0.fscm graph.csv; do
    if [ ! -f "$data_root/$data_file" ]; then
        printf 'Missing data file: %s\n' "$data_root/$data_file" >&2
        missing=1
    fi
done

if [ "$missing" -ne 0 ]; then
    printf '%s\n' 'Set VIOLET_DATA_ROOT to a folder containing the four data files.' >&2
    exit 1
fi

export VIOLET_DATA_ROOT="$data_root"
export VIOLET_IMAGE_TAG="${VIOLET_IMAGE_TAG:-latest}"

printf 'Pulling Violet images (tag: %s)...\n' "$VIOLET_IMAGE_TAG"
docker compose -f "$compose_file" pull

printf 'Starting Violet services with data from %s...\n' "$VIOLET_DATA_ROOT"
docker compose -f "$compose_file" up -d --remove-orphans
printf '%s\n' 'Violet services are running.'
