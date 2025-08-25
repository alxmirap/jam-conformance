#!/bin/bash

set -e

DEFAULT_SOCK="/tmp/jam_target.sock"

# Target configuration using associative array with dot notation
declare -A TARGETS

# === VINWOLF ===
TARGETS[vinwolf.repo]="bloppan/conformance_testing"
TARGETS[vinwolf.cmd.linux]="./linux/tiny/x86_64/vinwolf-target --fuzz $DEFAULT_SOCK"

# === JAMZIG ===
TARGETS[jamzig.repo]="jamzig/conformance-releases"
TARGETS[jamzig.cmd.linux]="./tiny/linux/x86_64/jam_conformance_target -vv --socket $DEFAULT_SOCK"
TARGETS[jamzig.cmd.macos]="./tiny/macos/aarch64/jam_conformance_target -vv --socket $DEFAULT_SOCK"
 
# === PYJAMAZ ===
TARGETS[pyjamaz.repo]="jamdottech/pyjamaz-conformance-releases"
TARGETS[pyjamaz.post]="cd gp-0.6.7 && unzip pyjamaz-linux-x86_64.zip"
TARGETS[pyjamaz.cmd]="./gp-0.6.7/pyjamaz fuzzer target --socket-path $DEFAULT_SOCK"

# === JAMPY ===
TARGETS[jampy.repo]="dakk/jampy-releases"
TARGETS[jampy.post]="cd dist && unzip jampy-target-0.7.0_x86-64.zip"
TARGETS[jampy.cmd]="./dist/jampy-target-0.7.0_x86-64/jampy-target-0.7.0_x86-64 --socket-file $DEFAULT_SOCK"

# === JAMDUNA ===
TARGETS[jamduna.file.linux]="duna_target_linux"
TARGETS[jamduna.file.macos]="duna_target_mac"
TARGETS[jamduna.repo]="jam-duna/jamtestnet"
TARGETS[jamduna.cmd.linux]="./duna_target_linux -socket $DEFAULT_SOCK"
TARGETS[jamduna.cmd.macos]="./duna_target_mac -socket $DEFAULT_SOCK"

# === JAMIXIR ===
TARGETS[jamixir.file.linux]="jamixir_linux-x86-64-gp_0.6.7_v0.2.6_tiny.tar.gz"
TARGETS[jamixir.repo]="jamixir/jamixir-releases"
TARGETS[jamixir.cmd.linux]="./jamixir fuzzer --socket-path $DEFAULT_SOCK"

# === JAVAJAM ===
TARGETS[javajam.file]="javajam-linux-x86_64.zip"
TARGETS[javajam.file.macos]="javajam-macos-aarch64.zip"
TARGETS[javajam.repo]="javajamio/javajam-releases"
TARGETS[javajam.cmd]="./bin/javajam fuzz $DEFAULT_SOCK"

# === JAMZILLA ===
TARGETS[jamzilla.file.linux]="fuzzserver-tiny-amd64-linux"
TARGETS[jamzilla.file.macos]="fuzzserver-tiny-arm64-darwin"
TARGETS[jamzilla.repo]="ascrivener/jamzilla-conformance-releases"
TARGETS[jamzilla.cmd.linux]="./fuzzserver-tiny-amd64-linux -socket $DEFAULT_SOCK"
TARGETS[jamzilla.cmd.macos]="./fuzzserver-tiny-arm64-darwin -socket $DEFAULT_SOCK"

# === SPACEJAM ===
TARGETS[spacejam.file.linux]="spacejam-0.6.7-linux-amd64.tar.gz"
TARGETS[spacejam.file.macos]="spacejam-0.6.7-macos-arm64.tar.gz"
TARGETS[spacejam.repo]="spacejamapp/specjam"
TARGETS[spacejam.cmd]="./spacejam -vv fuzz target $DEFAULT_SOCK"

# === BOKA ===
TARGETS[boka.image]="acala/boka:latest"
TARGETS[boka.cmd]="fuzz target --socket-path $DEFAULT_SOCK"

# === TURBOJAM ===
TARGETS[turbojam.image]="r2rationality/turbojam-fuzz:latest"
TARGETS[turbojam.cmd]="fuzzer-api $DEFAULT_SOCK"

# === GRAYMATTER ===
TARGETS[graymatter.image]="ghcr.io/jambrains/graymatter/gm:conformance-fuzzer-latest"
TARGETS[graymatter.cmd]="fuzz-m1-target --listen $DEFAULT_SOCK"


### Auxiliary functions:
show_usage() {
    local script_name=$1
    echo "Usage: $script_name <get|run> <target>"
    echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
    echo "Available OSes: linux, macos"
    echo "Default OS: linux (auto-detected)"
}

validate_target() {
    local target=$1
    if [[ "$target" != "all" ]] && ! is_repo_target "$target" && ! is_docker_target "$target"; then
        echo "Unknown target '$target'" >&2
        echo "Available targets: ${AVAILABLE_TARGETS[*]} all" >&2
        return 1
    fi
    return 0
}

validate_os() {
    local os=$1
    if [[ "$os" != "linux" && "$os" != "macos" ]]; then
        echo "Error: Unsupported OS '$os'" >&2
        echo "Supported OSes: linux, macos" >&2
        return 1
    fi
    return 0
}

is_docker_target() {
    local target=$1
    [[ -v TARGETS[$target.image] ]]
}

is_repo_target() {
    local target=$1
    [[ -v TARGETS[$target.repo] ]]
}

# Get list of available targets
get_available_targets() {
    local targets=()
    for key in "${!TARGETS[@]}"; do
        local target_name="${key%%.*}"
        if [[ ! " ${targets[@]} " =~ " ${target_name} " ]]; then
            targets+=("$target_name")
        fi
    done
    printf '%s\n' "${targets[@]}" | sort
}

AVAILABLE_TARGETS=($(get_available_targets))

# Returns 0 if the target supports the given os, 1 otherwise
target_supports_os() {
    local target="$1"
    local os="$2"
    # If no file entry, support all OSes
    if [[ ! -v TARGETS[$target.file] ]]; then
        return 0
    fi
    # If file.<os> entry exists, support only that OS
    if [[ -v TARGETS[$target.file.$os] ]]; then
        return 0
    fi
    # If file entry exists, support both OSes
    if [[ -v TARGETS[$target.file] ]]; then
        return 0
    fi
    echo "Error: No $os version available for $target" >&2
    return 1
}

# Function to get the correct file for a target and os
get_target_file() {
    local target=$1
    local os=$2
    local file="${TARGETS[$target.file.$os]}"
    if [ -z "$file" ]; then
        file="${TARGETS[$target.file]}"
        if [ -z "$file" ]; then
            echo ""
            return 1
        fi
    fi
    echo "$file"
    return 0
}

clone_github_repo() {
    local target=$1
    local repo=$2
    local temp_dir=$(mktemp -d)
    git clone "https://github.com/$repo" --depth 1 "$temp_dir"
    local commit_hash=$(cd "$temp_dir" && git rev-parse --short HEAD)
    local target_dir=$(realpath "targets/$target")
    mkdir -p "$target_dir"
    local target_dir_rev="$target_dir/$commit_hash"
    mv "$temp_dir" "$target_dir_rev"
    rm -f "$target_dir/latest"
    ln -s "$target_dir_rev" "$target_dir/latest"
    echo "Cloned to $target_dir"

    local post="${TARGETS[$target.post]}"
    if [ ! -z "$post" ]; then
        pushd $target_dir_rev
        bash -c "$post"
        popd
    fi
    
    return 0
}

pull_docker_image() {
    local target=$1
    local docker_image="${TARGETS[$target.image]}"

    if [ -z "$docker_image" ]; then
        echo "Error: No Docker image specified for $target"
        return 1
    fi

    echo "Pulling Docker image: $docker_image"

    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed or not in PATH"
        return 1
    fi

    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running or not accessible"
        echo "Please start Docker and try again"
        return 1
    fi
    if ! docker pull "$docker_image"; then
        echo "Error: Failed to pull Docker image $docker_image"
        return 1
    fi

    echo "Successfully pulled Docker image: $docker_image"

    return 0
}

download_github_release() {
    local target=$1
    local os=$2
    local repo="${TARGETS[$target.repo]}"
    local file=$(get_target_file "$target" "$os")

    if [ -z "$repo" ]; then
        echo "Error: missing repository information for $target"
        return 1
    fi

    if [ -z "$file" ]; then
        echo "Info: No release file specified for $target on $os, cloning repository instead"
        clone_github_repo "$target" "$repo"
        return 0
    fi

    echo "Fetching latest release information..."

    # Get the latest release tag from GitHub API
    local latest_tag=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$latest_tag" ]; then
        echo "Error: Could not fetch latest release tag"
        return 1
    fi

    echo "Latest version: $latest_tag"

    # Construct download URL
    local download_url="https://github.com/$repo/releases/download/$latest_tag/$file"

    echo "Downloading from: $download_url"

    # Download the file
    curl -L -o "$file" "$download_url"

    if [ $? -ne 0 ]; then
        echo "Error: Download failed"
        return 1
    fi

    echo "Successfully downloaded $file"
    echo "File size: $(ls -lh $file | awk '{print $5}')"

    local target_dir=$(realpath "targets/$target")
    local target_dir_rev="$target_dir/${latest_tag}"

    rm -f "$target_dir/latest"
    ln -s "$target_dir_rev" "$target_dir/latest"

    mkdir -p "$target_dir_rev"
    mv "$file" "$target_dir_rev/"

    # Check if file is an archive and extract it, or make it executable
    local post="${TARGETS[$target.post]}"
    if [ ! -z "$post" ]; then
        cd "$target_dir_rev"
        pushd $target_dir_rev
        bash -c "$post"
        popd
    elif [[ "$file" == *.zip ]]; then
        echo "Extracting zip archive: $file"
        unzip "$file"
        rm "$file"
    elif [[ "$file" == *.tar.gz ]] || [[ "$file" == *.tgz ]]; then
        echo "Extracting tar.gz archive: $file"
        tar -xzf "$file"
        rm "$file"
    elif [[ "$file" == *.tar ]]; then
        echo "Extracting tar archive: $file"
        tar -xf "$file"
        rm "$file"
    else
        echo "Making file executable: $file"
        chmod +x "$file"
    fi
    cd - > /dev/null
}

run() {
    local target="$1"
    local os="${2:-linux}"
    local command=""
    # Prefer os-specific command, fallback to generic
    if [[ -v TARGETS[$target.cmd.$os] ]]; then
        command="${TARGETS[$target.cmd.$os]}"
    elif [[ -v TARGETS[$target.cmd] ]]; then
        command="${TARGETS[$target.cmd]}"
    else
        echo "Error: No run command specified for $target on $os"
        return 1
    fi

    target_dir=$(find targets -name "$target*" -type d | head -1)
    target_rev=$(realpath "$target_dir/latest")
    echo "Run $target on $target_rev"

    # Set up trap to cleanup on exit
    cleanup() {
        # Prevent multiple cleanup calls
        if [ "$CLEANUP_DONE" = "true" ]; then
            return
        fi
        CLEANUP_DONE=true

        echo "Cleaning up $target..."
        if [ ! -z "$TARGET_PID" ]; then
            echo "Killing target $TARGET_PID..."
            kill -TERM $TARGET_PID 2>/dev/null || true
            sleep 1
            # Force kill if still running
            kill -KILL $TARGET_PID 2>/dev/null || true
        fi
        rm -f "$DEFAULT_SOCK"
    }

    trap cleanup EXIT INT TERM

    pushd "$target_rev" > /dev/null
    bash -c "$command" &
    TARGET_PID=$!
    popd > /dev/null

    echo "Waiting for target termination (pid=$TARGET_PID)"
    wait $TARGET_PID
}

run_docker_image() {
    local target="$1"
    local image="${TARGETS[$target.image]}"
    local command="${TARGETS[$target.cmd]}"

    echo "Run $target via Docker"

    if ! docker image inspect "$image" >/dev/null 2>&1; then
        echo "Error: Docker image '$image' not found locally."
        echo "Please run: $0 get $target"
        exit 1
    fi

    cleanup_docker() {
        echo "Cleaning up Docker container $target..."
        docker kill "$target" 2>/dev/null || true
        rm -f "$DEFAULT_SOCK"
    }

    trap cleanup_docker EXIT INT TERM

    docker run --rm --pull=never --platform linux/amd64 --name "$target" -v /tmp:/tmp --user "$(id -u):$(id -g)" "$image" $command &
    TARGET_PID=$!

    sleep 3
    echo "Waiting for target termination (pid=$TARGET_PID)"
    wait $TARGET_PID
}

### Main script logic
if [ $# -lt 2 ]; then
    show_usage "$0"
    exit 1
fi

ACTION="$1"
TARGET="$2"
# Detect OS using uname
UNAME_S=$(uname -s)
case "$UNAME_S" in
    Linux)
        OS="linux"
        ;;
    Darwin)
        OS="macos"
        ;;
    *)
        echo "Unsupported OS: $UNAME_S" >&2
        exit 1
        ;;
esac

validate_os "$OS" || exit 1
validate_target "$TARGET" || exit 1

echo "Action: $ACTION, Target: $TARGET, OS: $OS"


case "$ACTION" in
    "get")
        if [ "$TARGET" = "all" ]; then
            echo "Downloading all targets: ${AVAILABLE_TARGETS[*]}"
            failed_targets=()
            for target in "${AVAILABLE_TARGETS[@]}"; do
                echo "Downloading $target for $OS..."
                if is_repo_target "$target"; then
                    if target_supports_os "$target" "$OS"; then
                        if ! download_github_release "$target" "$OS"; then
                            echo "Failed to download $target"
                            failed_targets+=("$target")
                        fi
                    else
                        echo "Skipping $target: No $OS support available"
                    fi
                elif is_docker_target "$target"; then
                    if ! pull_docker_image "$target"; then
                        echo "Failed to pull Docker image for $target"
                        failed_targets+=("$target")
                    fi
                else
                    echo "Error: Unknown target type for $target"
                    failed_targets+=("$target")
                fi
                echo ""
            done
            # Report summary
            if [ ${#failed_targets[@]} -eq 0 ]; then
                echo "All targets downloaded successfully!"
            else
                echo "Failed to download the following targets: ${failed_targets[*]}"
                echo "Successfully downloaded: $((${#AVAILABLE_TARGETS[@]} - ${#failed_targets[@]})) out of ${#AVAILABLE_TARGETS[@]} targets"
                exit 1
            fi
        elif is_repo_target "$TARGET"; then
            if target_supports_os "$TARGET" "$OS"; then
                download_github_release "$TARGET" "$OS"
            else
                exit 1
            fi
        elif is_docker_target "$TARGET"; then
            pull_docker_image "$TARGET"
        else
            echo "Unknown target '$TARGET'"
            echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
            exit 1
        fi
        ;;
    "run")
        if is_docker_target "$TARGET"; then
            run_docker_image $TARGET
        elif is_repo_target "$TARGET"; then
            run $TARGET $OS
        else
            echo "Unknown target '$TARGET'"
            echo "Available targets: ${AVAILABLE_TARGETS[*]}"
            exit 1
        fi
        ;;
    *)
        echo "Unknown action '$ACTION'"
        echo "Usage: $0 <get|run> <target>"
        exit 1
        ;;
esac
