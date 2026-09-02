#!/usr/bin/env bash
# A safe, configurable wrapper for the Ubuntu Workshop workflow.
#
# Installation is limited to the LXD and Workshop snaps. Project creation,
# Workshop lifecycle operations, interfaces, SDKs, sketches, diagnostics, and
# native CLI passthrough are exposed as explicit subcommands.

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
readonly SCRIPT_PATH

PROJECT_DIR="${UWS_PROJECT_DIR:-$PWD}"
WORKSHOP_NAME="${UWS_WORKSHOP_NAME:-dev}"
BASE_IMAGE="${UWS_BASE:-ubuntu@24.04}"
SDK_SPEC="${UWS_SDKS:-ollama/cpu/stable}"
MODEL_NAME="${UWS_MODEL:-}"
LXD_CHANNEL="${UWS_LXD_CHANNEL:-6/stable}"
SNAP_BIN_DIR="${UWS_SNAP_BIN:-/snap/bin}"
CONFIG_FILE="${UWS_CONFIG_FILE:-}"
USE_GIT="${UWS_USE_GIT:-1}"
ADD_OLLAMA_ACTION="${UWS_OLLAMA_ACTION:-1}"

DRY_RUN="${UWS_DRY_RUN:-0}"
JSON_OUTPUT="${UWS_JSON_OUTPUT:-0}"
ASSUME_YES=0

SNAP_COMMAND=""
WORKSHOP_COMMAND=""
PRIVILEGE_PREFIX=()
TARGET_WORKSHOPS=()
TARGET_ARGS=()
COMMAND="install"
COMMAND_ARGS=()
DOCTOR_STATUS=0

log() {
    printf '[%s] %s\n' "$SCRIPT_NAME" "$*" >&2
}

die() {
    log "ERROR: $*"
    exit 1
}

# The ERR trap invokes this handler indirectly; newer ShellCheck versions
# otherwise report the handler body as unreachable.
# shellcheck disable=SC2317,SC2329
on_error() {
    local status=$?
    log "Command failed with status ${status} at line ${BASH_LINENO[0]:-unknown}: ${BASH_COMMAND}"
    exit "$status"
}

trap on_error ERR

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [global options] <command> [arguments...]

With no command, installs or refreshes LXD and Workshop.

Global options (must appear before the command):
  --project-dir DIR       Project directory (default: current directory).
  --workshop NAME         Target workshop; repeat for multi-workshop commands.
  --base BASE             Workshop base (default: ubuntu@24.04).
  --sdks SDKS             Comma-separated SDK list (default: ollama/cpu/stable).
  --model MODEL           Model to pull during bootstrap or pull-model.
  --lxd-channel CHANNEL   LXD snap channel (default: 6/stable).
  --config FILE           Allow-listed KEY=VALUE configuration file.
  --snap-bin DIR          Snap command directory (default: /snap/bin).
  --no-git / --git        Control git init during init (default: enabled).
  --ollama-action          Add the pull action when Ollama is selected.
  --no-ollama-action       Do not add the Ollama pull action.
  --yes                   Confirm destructive operations.
  --dry-run / --plan      Print operations without changing state.
  --json                  Wrap supported query output in JSON.
  -h, --help              Show this help message.

Bootstrap and lifecycle:
  install init bootstrap launch refresh start stop restore remove
  list status info actions changes tasks warnings okay

Execution and interfaces:
  exec shell run ollama pull-model
  connections connect disconnect remount

SDKs, sketches, and passthrough:
  sdk sdk-find sdk-info sdk-list sdkcraft sdkcraft-install sdkcraft-refresh sketch-sdk sketches
  sketch-stash sketch-restore sketch-remove sketch-eject
  native workshop workshopctl version

Operations and integration:
  doctor completion ci

Examples:
  ${SCRIPT_NAME} install
  ${SCRIPT_NAME} --project-dir ./my-project bootstrap
  ${SCRIPT_NAME} --project-dir ./my-project --workshop dev exec -- ls /project
  ${SCRIPT_NAME} --project-dir ./my-project --json status
  ${SCRIPT_NAME} completion bash > ~/.local/share/bash-completion/workshop-automated-installer

Configuration keys:
  UWS_PROJECT_DIR UWS_WORKSHOP_NAME UWS_BASE UWS_SDKS UWS_MODEL
  UWS_LXD_CHANNEL UWS_SNAP_BIN UWS_USE_GIT UWS_OLLAMA_ACTION UWS_JSON_OUTPUT
EOF
}

json_quote() {
    local value=$1

    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$value" | python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
        return
    fi

    value=${value//\\/\\\\}
    value=${value//"/\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    value=${value//$'\b'/\\b}
    value=${value//$'\f'/\\f}
    printf '"%s"' "$value"
}

emit_json_result() {
    local command_name=$1
    local status=$2
    local output=$3
    local command_json
    local project_json
    local workshop_json
    local output_json

    command_json="$(json_quote "$command_name")"
    project_json="$(json_quote "$PROJECT_DIR")"
    workshop_json="$(json_quote "$WORKSHOP_NAME")"
    output_json="$(json_quote "$output")"
    printf '{"command":%s,"project_dir":%s,"workshop":%s,"exit_code":%d,"output":%s}\n' \
        "$command_json" "$project_json" "$workshop_json" "$status" "$output_json"
}

print_plan() {
    printf '[plan]'
    printf ' %q' "$@"
    printf '\n'
}

print_project_plan() {
    printf '[plan] (cd -- %q &&' "$PROJECT_DIR"
    printf ' %q' "$@"
    printf ')\n'
}

run_command() {
    if ((DRY_RUN)); then
        print_plan "$@"
    else
        "$@"
    fi
}

run_project_command() {
    if ((DRY_RUN)); then
        print_project_plan "$@"
    else
        (cd -- "$PROJECT_DIR" && "$@")
    fi
}

trim() {
    local value=$1
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

normalize_boolean() {
    case "$1" in
        1|true|TRUE|yes|YES|on|ON)
            printf '1'
            ;;
        0|false|FALSE|no|NO|off|OFF)
            printf '0'
            ;;
        *)
            die "Expected a boolean value, got: $1"
            ;;
    esac
}

validate_name() {
    local label=$1
    local value=$2
    [[ "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] \
        || die "Invalid ${label}: ${value}"
}

validate_scalar() {
    local label=$1
    local value=$2
    [[ -n "$value" ]] || die "${label} cannot be empty."
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] \
        || die "${label} cannot contain newlines."
}

load_config_file() {
    local line
    local key
    local value

    [[ -n "$CONFIG_FILE" ]] || return 0
    [[ -f "$CONFIG_FILE" ]] || die "Configuration file not found: ${CONFIG_FILE}"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line="$(trim "$line")"
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || die "Invalid configuration line: ${line}"

        key="$(trim "${line%%=*}")"
        value="$(trim "${line#*=}")"
        [[ "$key" =~ ^UWS_[A-Z0-9_]+$ ]] \
            || die "Unsupported configuration key: ${key}"

        case "$key" in
            UWS_PROJECT_DIR) PROJECT_DIR=$value ;;
            UWS_WORKSHOP_NAME) WORKSHOP_NAME=$value ;;
            UWS_BASE) BASE_IMAGE=$value ;;
            UWS_SDKS) SDK_SPEC=$value ;;
            UWS_MODEL) MODEL_NAME=$value ;;
            UWS_LXD_CHANNEL) LXD_CHANNEL=$value ;;
            UWS_SNAP_BIN) SNAP_BIN_DIR=$value ;;
            UWS_USE_GIT) USE_GIT="$(normalize_boolean "$value")" ;;
            UWS_OLLAMA_ACTION) ADD_OLLAMA_ACTION="$(normalize_boolean "$value")" ;;
            UWS_JSON_OUTPUT) JSON_OUTPUT="$(normalize_boolean "$value")" ;;
            *) die "Unsupported configuration key: ${key}" ;;
        esac
    done < "$CONFIG_FILE"
}

find_config_path() {
    while (($# > 0)); do
        case "$1" in
            --config)
                (($# > 1)) || die "--config requires a file path."
                CONFIG_FILE=$2
                shift 2
                ;;
            --config=*)
                CONFIG_FILE=${1#*=}
                shift
                ;;
            --project-dir|--workshop|--base|--sdks|--model|--lxd-channel|--snap-bin)
                (($# > 1)) || die "$1 requires a value."
                shift 2
                ;;
            --project-dir=*|--workshop=*|--base=*|--sdks=*|--model=*|--lxd-channel=*|--snap-bin=*)
                shift
                ;;
            --dry-run|--plan|--json|--no-git|--git|--yes|--ollama-action|--no-ollama-action)
                shift
                ;;
            --)
                return 0
                ;;
            -h|--help)
                return 0
                ;;
            *)
                return 0
                ;;
        esac
    done
}

parse_arguments() {
    local option_value

    while (($# > 0)); do
        case "$1" in
            --project-dir)
                (($# > 1)) || die "--project-dir requires a directory."
                PROJECT_DIR=$2
                shift 2
                ;;
            --project-dir=*)
                PROJECT_DIR=${1#*=}
                shift
                ;;
            --workshop)
                (($# > 1)) || die "--workshop requires a name."
                WORKSHOP_NAME=$2
                TARGET_WORKSHOPS+=("$2")
                shift 2
                ;;
            --workshop=*)
                option_value=${1#*=}
                WORKSHOP_NAME=$option_value
                TARGET_WORKSHOPS+=("$option_value")
                shift
                ;;
            --base)
                (($# > 1)) || die "--base requires a base image."
                BASE_IMAGE=$2
                shift 2
                ;;
            --base=*)
                BASE_IMAGE=${1#*=}
                shift
                ;;
            --sdks)
                (($# > 1)) || die "--sdks requires an SDK list."
                SDK_SPEC=$2
                shift 2
                ;;
            --sdks=*)
                SDK_SPEC=${1#*=}
                shift
                ;;
            --model)
                (($# > 1)) || die "--model requires a model name."
                MODEL_NAME=$2
                shift 2
                ;;
            --model=*)
                MODEL_NAME=${1#*=}
                shift
                ;;
            --lxd-channel)
                (($# > 1)) || die "--lxd-channel requires a channel."
                LXD_CHANNEL=$2
                shift 2
                ;;
            --lxd-channel=*)
                LXD_CHANNEL=${1#*=}
                shift
                ;;
            --snap-bin)
                (($# > 1)) || die "--snap-bin requires a directory."
                SNAP_BIN_DIR=$2
                shift 2
                ;;
            --snap-bin=*)
                SNAP_BIN_DIR=${1#*=}
                shift
                ;;
            --config)
                (($# > 1)) || die "--config requires a file path."
                CONFIG_FILE=$2
                shift 2
                ;;
            --config=*)
                CONFIG_FILE=${1#*=}
                shift
                ;;
            --no-git)
                USE_GIT=0
                shift
                ;;
            --git)
                USE_GIT=1
                shift
                ;;
            --ollama-action)
                ADD_OLLAMA_ACTION=1
                shift
                ;;
            --no-ollama-action)
                ADD_OLLAMA_ACTION=0
                shift
                ;;
            --yes)
                ASSUME_YES=1
                shift
                ;;
            --dry-run|--plan)
                DRY_RUN=1
                shift
                ;;
            --json)
                JSON_OUTPUT=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                if (($# > 0)); then
                    COMMAND=$1
                    shift
                    COMMAND_ARGS=("$@")
                fi
                return 0
                ;;
            -*)
                die "Unknown global option: $1"
                ;;
            *)
                COMMAND=$1
                shift
                COMMAND_ARGS=("$@")
                return 0
                ;;
        esac
    done
}

validate_options() {
    PROJECT_DIR="$(trim "$PROJECT_DIR")"
    WORKSHOP_NAME="$(trim "$WORKSHOP_NAME")"
    BASE_IMAGE="$(trim "$BASE_IMAGE")"
    SDK_SPEC="$(trim "$SDK_SPEC")"
    MODEL_NAME="$(trim "$MODEL_NAME")"
    LXD_CHANNEL="$(trim "$LXD_CHANNEL")"
    SNAP_BIN_DIR="$(trim "$SNAP_BIN_DIR")"

    USE_GIT="$(normalize_boolean "$USE_GIT")"
    ADD_OLLAMA_ACTION="$(normalize_boolean "$ADD_OLLAMA_ACTION")"
    DRY_RUN="$(normalize_boolean "$DRY_RUN")"
    JSON_OUTPUT="$(normalize_boolean "$JSON_OUTPUT")"

    validate_scalar project-dir "$PROJECT_DIR"
    validate_name workshop "$WORKSHOP_NAME"
    validate_scalar base "$BASE_IMAGE"
    validate_scalar sdks "$SDK_SPEC"
    validate_scalar lxd-channel "$LXD_CHANNEL"
    validate_scalar snap-bin "$SNAP_BIN_DIR"
    if [[ -n "$MODEL_NAME" ]]; then
        validate_scalar model "$MODEL_NAME"
    fi

    local target
    for target in "${TARGET_WORKSHOPS[@]}"; do
        validate_name workshop "$target"
    done

    if [[ "$COMMAND" == "init" && ${#TARGET_WORKSHOPS[@]} -gt 1 ]]; then
        die "init accepts one workshop name; repeat --workshop only for multi-workshop commands."
    fi
}

json_command_supported() {
    case "$COMMAND" in
        list|status|info|actions|changes|tasks|connections|doctor|sdk|sdk-find|sdk-info|sdk-list|version)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

resolve_executable() {
    local command_name=$1
    local resolved

    if resolved="$(command -v "$command_name" 2>/dev/null)"; then
        printf '%s\n' "$resolved"
    elif [[ -x "${SNAP_BIN_DIR}/${command_name}" ]]; then
        printf '%s/%s\n' "$SNAP_BIN_DIR" "$command_name"
    else
        return 1
    fi
}

require_command() {
    local command_name=$1
    resolve_executable "$command_name" >/dev/null \
        || die "Required command not found: ${command_name}"
}

configure_privileges() {
    if ((EUID == 0)); then
        PRIVILEGE_PREFIX=()
    else
        PRIVILEGE_PREFIX=(sudo)
    fi

    if ((DRY_RUN)); then
        return 0
    fi

    require_command snap
    SNAP_COMMAND="$(resolve_executable snap)"
    if ((EUID != 0)); then
        require_command sudo
        "${PRIVILEGE_PREFIX[@]}" -v
    fi
}

snap_call() {
    local snap_executable="${SNAP_COMMAND:-snap}"
    run_command "${PRIVILEGE_PREFIX[@]}" "$snap_executable" "$@"
}

snap_is_installed() {
    "$SNAP_COMMAND" list "$1" >/dev/null 2>&1
}

show_snap_install_or_refresh() {
    local snap_name=$1
    shift
    local -a install_arguments=("$@")
    local -a refresh_arguments=()

    if [[ "$snap_name" == "lxd" ]]; then
        refresh_arguments=(--channel="$LXD_CHANNEL")
    fi

    log "Would install ${snap_name} if absent, otherwise refresh it."
    run_command "${PRIVILEGE_PREFIX[@]}" snap install "${install_arguments[@]}" "$snap_name"
    run_command "${PRIVILEGE_PREFIX[@]}" snap refresh "${refresh_arguments[@]}" "$snap_name"
}

install_or_refresh_lxd() {
    if ((DRY_RUN)); then
        show_snap_install_or_refresh lxd --channel="$LXD_CHANNEL"
    elif snap_is_installed lxd; then
        log "Refreshing LXD on channel ${LXD_CHANNEL}."
        snap_call refresh --channel="$LXD_CHANNEL" lxd
    else
        log "Installing LXD on channel ${LXD_CHANNEL}."
        snap_call install --channel="$LXD_CHANNEL" lxd
    fi
}

install_or_refresh_workshop() {
    if ((DRY_RUN)); then
        show_snap_install_or_refresh workshop --classic
    elif snap_is_installed workshop; then
        log "Refreshing Workshop."
        snap_call refresh workshop
    else
        log "Installing Workshop in classic mode."
        snap_call install --classic workshop
    fi
}

install_or_refresh_sdkcraft() {
    if ((DRY_RUN)); then
        log "Would install SDKcraft in classic mode if absent, otherwise refresh it."
        run_command "${PRIVILEGE_PREFIX[@]}" snap install --classic sdkcraft
        run_command "${PRIVILEGE_PREFIX[@]}" snap refresh sdkcraft
    elif snap_is_installed sdkcraft; then
        log "Refreshing SDKcraft."
        snap_call refresh sdkcraft
    else
        log "Installing SDKcraft in classic mode."
        snap_call install --classic sdkcraft
    fi
}

ensure_lxd_service() {
    log "Ensuring the LXD snap service is running."
    snap_call start lxd
}

verify_installation() {
    local lxd_executable
    local workshop_executable
    local lxd_version
    local workshop_version
    local service_output

    lxd_executable="$(resolve_executable lxd)" \
        || die "LXD was installed but its executable is unavailable."
    workshop_executable="$(resolve_executable workshop)" \
        || die "Workshop was installed but its executable is unavailable."

    if ! lxd_version="$("$lxd_executable" --version 2>&1)"; then
        die "LXD version check failed: ${lxd_version}"
    fi
    [[ -n "$lxd_version" ]] || die "LXD version check returned no output."
    log "LXD version: ${lxd_version}"

    if ! workshop_version="$("$workshop_executable" --version 2>&1)"; then
        if ! workshop_version="$("$workshop_executable" version 2>&1)"; then
            die "Workshop version check failed."
        fi
    fi
    [[ -n "$workshop_version" ]] || die "Workshop version check returned no output."
    log "Workshop version: ${workshop_version}"

    if ! service_output="$("${PRIVILEGE_PREFIX[@]}" "$SNAP_COMMAND" services lxd 2>&1)"; then
        die "Unable to inspect the LXD snap service: ${service_output}"
    fi
    printf '%s\n' "$service_output"
    if ! awk 'NR > 1 && $0 ~ /[[:space:]]active([[:space:]]|$)/ { found = 1 } END { if (found) exit 0; exit 1 }' <<<"$service_output"; then
        die "The LXD snap service is not active."
    fi

    if ((EUID != 0)) && command -v getent >/dev/null 2>&1; then
        local current_user
        current_user="$(id -un)"
        if getent group lxd >/dev/null 2>&1 && ! id -nG "$current_user" | awk '{ for (i = 1; i <= NF; i++) if ($i == "lxd") found = 1 } END { exit(found ? 0 : 1) }'; then
            log "Note: ${current_user} is not in the lxd group; add it explicitly and start a new login session if Workshop access requires it."
        fi
    fi
}

cmd_install() {
    (($# == 0)) || die "install does not accept positional arguments."
    configure_privileges
    install_or_refresh_lxd
    install_or_refresh_workshop
    ensure_lxd_service
    if ((DRY_RUN == 0)); then
        verify_installation
        log "Workshop installation completed successfully."
    fi
}

cmd_sdkcraft_install() {
    (($# == 0)) || die "sdkcraft-install does not accept positional arguments."
    configure_privileges
    install_or_refresh_sdkcraft
}

cmd_sdkcraft_refresh() {
    (($# == 0)) || die "sdkcraft-refresh does not accept positional arguments."
    configure_privileges
    if ((DRY_RUN)); then
        run_command "${PRIVILEGE_PREFIX[@]}" snap refresh sdkcraft
    else
        log "Refreshing SDKcraft."
        snap_call refresh sdkcraft
    fi
}

require_project() {
    if [[ ! -d "$PROJECT_DIR" ]]; then
        if ((DRY_RUN)); then
            log "Project directory is absent; continuing because this is a dry run: ${PROJECT_DIR}"
            return 0
        fi
        die "Project directory not found: ${PROJECT_DIR}; run init first or pass --project-dir."
    fi
    PROJECT_DIR="$(cd -- "$PROJECT_DIR" && pwd -P)"
}

require_workshop() {
    if ((DRY_RUN)); then
        WORKSHOP_COMMAND="${WORKSHOP_COMMAND:-workshop}"
        return 0
    fi
    WORKSHOP_COMMAND="$(resolve_executable workshop)" \
        || die "Workshop CLI not found; run install first."
}

run_project_workshop() {
    require_project
    require_workshop
    if ((DRY_RUN)); then
        print_project_plan "$WORKSHOP_COMMAND" "$@"
    else
        (cd -- "$PROJECT_DIR" && "$WORKSHOP_COMMAND" "$@")
    fi
}

run_project_query() {
    local native_command=$1
    shift
    local output
    local status

    require_project
    require_workshop
    if ((JSON_OUTPUT)); then
        if ((DRY_RUN)); then
            output="$(print_project_plan "$WORKSHOP_COMMAND" "$native_command" "$@")"
            emit_json_result "$native_command" 0 "$output"
            return 0
        fi
        if output="$(cd -- "$PROJECT_DIR" && "$WORKSHOP_COMMAND" "$native_command" "$@" 2>&1)"; then
            status=0
        else
            status=$?
        fi
        emit_json_result "$native_command" "$status" "$output"
        return "$status"
    fi
    run_project_workshop "$native_command" "$@"
}

run_tool() {
    local tool_name=$1
    shift
    local tool_executable
    local output
    local status

    if ((DRY_RUN)); then
        if ((JSON_OUTPUT)); then
            output="$(print_plan "$tool_name" "$@")"
            emit_json_result "$tool_name" 0 "$output"
        else
            print_plan "$tool_name" "$@"
        fi
        return 0
    fi

    tool_executable="$(resolve_executable "$tool_name")" \
        || die "Required command not found: ${tool_name}"
    if ((JSON_OUTPUT)); then
        if output="$("$tool_executable" "$@" 2>&1)"; then
            status=0
        else
            status=$?
        fi
        emit_json_result "$tool_name" "$status" "$output"
        return "$status"
    fi
    "$tool_executable" "$@"
}

run_project_tool() {
    local tool_name=$1
    shift
    local tool_executable
    local output
    local status

    require_project
    if ((DRY_RUN)); then
        if ((JSON_OUTPUT)); then
            output="$(print_project_plan "$tool_name" "$@")"
            emit_json_result "$tool_name" 0 "$output"
        else
            print_project_plan "$tool_name" "$@"
        fi
        return 0
    fi

    tool_executable="$(resolve_executable "$tool_name")" \
        || die "Required command not found: ${tool_name}"
    if ((JSON_OUTPUT)); then
        if output="$(cd -- "$PROJECT_DIR" && "$tool_executable" "$@" 2>&1)"; then
            status=0
        else
            status=$?
        fi
        emit_json_result "$tool_name" "$status" "$output"
        return "$status"
    fi
    (cd -- "$PROJECT_DIR" && "$tool_executable" "$@")
}

prepare_project_for_init() {
    if [[ -e "$PROJECT_DIR" && ! -d "$PROJECT_DIR" ]]; then
        die "Project path exists but is not a directory: ${PROJECT_DIR}"
    fi
    if ((DRY_RUN)); then
        if [[ ! -d "$PROJECT_DIR" ]]; then
            log "Would create project directory: ${PROJECT_DIR}"
            print_plan mkdir -p "$PROJECT_DIR"
        fi
        return 0
    fi
    mkdir -p "$PROJECT_DIR"
    PROJECT_DIR="$(cd -- "$PROJECT_DIR" && pwd -P)"
}

ensure_gitignore_entry() {
    local gitignore="$PROJECT_DIR/.gitignore"

    if [[ -e "$gitignore" && ! -f "$gitignore" ]]; then
        die ".gitignore exists but is not a regular file: ${gitignore}"
    fi
    if [[ -f "$gitignore" ]] && grep -Fxq '.workshop.lock' "$gitignore"; then
        return 0
    fi
    if [[ -s "$gitignore" ]] && [[ "$(tail -c 1 "$gitignore" | wc -l)" -eq 0 ]]; then
        printf '\n' >>"$gitignore"
    fi
    printf '.workshop.lock\n' >>"$gitignore"
}

append_ollama_action() {
    local definition="$PROJECT_DIR/.workshop/${WORKSHOP_NAME}.yaml"

    ((ADD_OLLAMA_ACTION)) || return 0
    [[ "$SDK_SPEC" == *ollama* ]] || return 0
    [[ -f "$definition" ]] || die "Workshop definition was not created: ${definition}"
    if grep -Eq '^[[:space:]]*actions:' "$definition"; then
        log "Existing actions section preserved in ${definition}."
        return 0
    fi
    if [[ -s "$definition" ]] && [[ "$(tail -c 1 "$definition" | wc -l)" -eq 0 ]]; then
        printf '\n' >>"$definition"
    fi
    printf '%s\n' 'actions:' '  pull: ollama pull "$@"' >>"$definition"
}

cmd_init() {
    local definition

    (($# == 0)) || die "init accepts options before the command and no positional arguments."
    validate_name workshop "$WORKSHOP_NAME"
    prepare_project_for_init
    definition="$PROJECT_DIR/.workshop/${WORKSHOP_NAME}.yaml"
    if [[ -e "$definition" ]]; then
        die "Workshop definition already exists; refusing to overwrite: ${definition}"
    fi

    if ((USE_GIT)); then
        if [[ ! -e "$PROJECT_DIR/.git" ]]; then
            if ((DRY_RUN)); then
                print_project_plan git init
            else
                require_command git
                run_project_command git init
            fi
        fi
    fi

    run_project_workshop init "$WORKSHOP_NAME" --base "$BASE_IMAGE" --sdks "$SDK_SPEC"
    if ((DRY_RUN)); then
        log "Would add .workshop.lock to ${PROJECT_DIR}/.gitignore."
        if ((ADD_OLLAMA_ACTION)) && [[ "$SDK_SPEC" == *ollama* ]]; then
            log "Would add the Ollama pull action to ${definition}."
        fi
    else
        ensure_gitignore_entry
        append_ollama_action
        log "Workshop definition created: ${definition}"
    fi
}

cmd_bootstrap() {
    (($# == 0)) || die "bootstrap does not accept positional arguments."
    cmd_install
    cmd_init
    cmd_lifecycle launch
    if [[ -n "$MODEL_NAME" ]]; then
        cmd_pull_model "$MODEL_NAME"
    fi
}

set_target_args() {
    local native_command=$1
    TARGET_ARGS=()
    case "$native_command" in
        launch|refresh|start|stop|restore|remove)
            TARGET_ARGS=("${TARGET_WORKSHOPS[@]}")
            ;;
        info|actions|connections|shell|exec|run|sketch-sdk)
            if ((${#TARGET_WORKSHOPS[@]} > 1)); then
                die "${native_command} accepts one --workshop target; use native for custom multi-target arguments."
            fi
            TARGET_ARGS=("${TARGET_WORKSHOPS[@]}")
            ;;
    esac
}

cmd_lifecycle() {
    local native_command=$1
    shift
    set_target_args "$native_command"
    run_project_workshop "$native_command" "${TARGET_ARGS[@]}" "$@"
}

cmd_query() {
    local native_command=$1
    shift
    set_target_args "$native_command"
    run_project_query "$native_command" "${TARGET_ARGS[@]}" "$@"
}

confirm_destructive() {
    local operation=$1
    local answer

    if ((DRY_RUN || ASSUME_YES)); then
        return 0
    fi
    if [[ ! -t 0 ]]; then
        die "${operation} requires --yes in a non-interactive session."
    fi
    read -r -p "${operation} can remove or reset Workshop data. Continue? [y/N] " answer
    case "$answer" in
        y|Y|yes|YES)
            ;;
        *)
            die "${operation} cancelled."
            ;;
    esac
}

cmd_remove() {
    confirm_destructive remove
    cmd_lifecycle remove "$@"
}

cmd_exec() {
    local -a command_arguments=("$@")
    if ((${#command_arguments[@]} > 0)) && [[ "${command_arguments[0]}" == "--" ]]; then
        command_arguments=("${command_arguments[@]:1}")
    fi
    ((${#command_arguments[@]} > 0)) || die "exec requires a command; use native exec for Workshop-specific flags."
    ((JSON_OUTPUT == 0)) || die "JSON output is not supported for interactive exec; use status/info or native exec."
    set_target_args exec
    run_project_workshop exec "${TARGET_ARGS[@]}" -- "${command_arguments[@]}"
}

cmd_shell() {
    ((JSON_OUTPUT == 0)) || die "JSON output is not supported for an interactive shell."
    set_target_args shell
    run_project_workshop shell "${TARGET_ARGS[@]}" "$@"
}

cmd_run() {
    local -a action_arguments=("$@")
    if ((${#action_arguments[@]} > 0)) && [[ "${action_arguments[0]}" == "--" ]]; then
        action_arguments=("${action_arguments[@]:1}")
    fi
    ((${#action_arguments[@]} > 0)) || die "run requires an action name."
    ((JSON_OUTPUT == 0)) || die "JSON output is not supported for run; use status/info or native run."
    set_target_args run
    run_project_workshop run "${TARGET_ARGS[@]}" -- "${action_arguments[@]}"
}

cmd_ollama() {
    cmd_exec ollama "$@"
}

cmd_pull_model() {
    local model=${1:-$MODEL_NAME}
    if [[ "$model" == "--" ]]; then
        shift
        model=${1:-$MODEL_NAME}
    fi
    [[ -n "$model" ]] || die "pull-model requires a model name or --model."
    (($# <= 1)) || die "pull-model accepts one model name."
    cmd_exec ollama pull "$model"
}

cmd_connectivity() {
    local native_command=$1
    shift
    run_project_workshop "$native_command" "$@"
}

cmd_sketch_sdk() {
    set_target_args sketch-sdk
    run_project_workshop sketch-sdk "${TARGET_ARGS[@]}" "$@"
}

cmd_sketch_operation() {
    local operation=$1
    shift
    if [[ "$operation" == "--remove" ]]; then
        confirm_destructive sketch-remove
    fi
    set_target_args sketch-sdk
    run_project_workshop sketch-sdk "${TARGET_ARGS[@]}" "$operation" "$@"
}

cmd_native() {
    local native_command=${1:-}
    [[ -n "$native_command" ]] || die "native requires a Workshop command."
    if [[ "$native_command" == "remove" ]]; then
        confirm_destructive remove
    elif [[ "$native_command" == "sketch-sdk" ]] && printf '%s\n' "$@" | grep -Fq -- '--remove'; then
        confirm_destructive sketch-remove
    fi
    run_project_workshop "$@"
}

cmd_doctor() {
    local doctor_status=0
    local kernel_name=''
    local snap_path=''
    local lxd_executable=''
    local workshop_executable=''
    local version_output=''
    local service_output=''
    local current_user=''
    local definitions='none'
    local -a report=()

    if kernel_name="$(uname -s 2>&1)" && [[ "$kernel_name" == "Linux" ]]; then
        report+=("platform: Linux")
    else
        report+=("platform: ${kernel_name:-unknown} (unsupported)")
        doctor_status=1
    fi

    if snap_path="$(resolve_executable snap 2>/dev/null)"; then
        report+=("snap: ${snap_path}")
    else
        report+=("snap: missing")
        doctor_status=1
    fi

    if lxd_executable="$(resolve_executable lxd 2>/dev/null)" && version_output="$("$lxd_executable" --version 2>&1)"; then
        report+=("lxd: ${version_output}")
    else
        report+=("lxd: unavailable")
        doctor_status=1
    fi

    if workshop_executable="$(resolve_executable workshop 2>/dev/null)" && version_output="$("$workshop_executable" --version 2>&1)"; then
        report+=("workshop: ${version_output}")
    elif workshop_executable="$(resolve_executable workshop 2>/dev/null)" && version_output="$("$workshop_executable" version 2>&1)"; then
        report+=("workshop: ${version_output}")
    else
        report+=("workshop: unavailable")
        doctor_status=1
    fi

    if [[ -n "$snap_path" ]]; then
        if service_output="$("$snap_path" services lxd 2>&1)"; then
            if awk 'NR > 1 && $0 ~ /[[:space:]]active([[:space:]]|$)/ { found = 1 } END { exit(found ? 0 : 1) }' <<<"$service_output"; then
                report+=("lxd-service: active")
            else
                report+=("lxd-service: inactive")
                doctor_status=1
            fi
        else
            report+=("lxd-service: unknown")
            doctor_status=1
        fi
    fi

    if [[ -d "$PROJECT_DIR" ]]; then
        PROJECT_DIR="$(cd -- "$PROJECT_DIR" && pwd -P)"
        report+=("project: ${PROJECT_DIR}")
        if [[ -d "$PROJECT_DIR/.workshop" ]]; then
            definitions="$(find "$PROJECT_DIR/.workshop" -maxdepth 1 -type f -name '*.yaml' -printf '%f\n' | sort | paste -sd, -)"
            [[ -n "$definitions" ]] || definitions='none'
        fi
        report+=("definitions: ${definitions}")
    else
        report+=("project: missing (${PROJECT_DIR})")
        doctor_status=1
    fi

    if [[ -f "$PROJECT_DIR/.gitignore" ]] && grep -Fxq '.workshop.lock' "$PROJECT_DIR/.gitignore"; then
        report+=('.workshop.lock: ignored')
    else
        report+=('.workshop.lock: not ignored')
    fi

    if ((EUID != 0)) && command -v id >/dev/null 2>&1; then
        current_user="$(id -un)"
        if id -nG "$current_user" | awk '{ for (i = 1; i <= NF; i++) if ($i == "lxd") found = 1 } END { exit(found ? 0 : 1) }'; then
            report+=("lxd-group: ${current_user} is a member")
        else
            report+=("lxd-group: ${current_user} is not a member")
        fi
    fi

    local report_output
    report_output="$(printf '%s\n' "${report[@]}")"
    if ((JSON_OUTPUT)); then
        emit_json_result doctor "$doctor_status" "$report_output"
    else
        printf '%s\n' "$report_output"
    fi
    DOCTOR_STATUS=$doctor_status
    return 0
}

completion_bash() {
    cat <<'EOF'
_uws_workshop_complete() {
    local current="${COMP_WORDS[COMP_CWORD]}"
    local commands="install init bootstrap launch refresh start stop restore remove list status info actions changes tasks warnings okay exec shell run ollama pull-model connections connect disconnect remount sdk sdk-find sdk-info sdk-list sdkcraft sdkcraft-install sdkcraft-refresh sketch-sdk sketches sketch-stash sketch-restore sketch-remove sketch-eject native workshop workshopctl version doctor completion ci"
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$current") )
    fi
}
complete -F _uws_workshop_complete workshop-automated-installer.sh
EOF
}

completion_zsh() {
    cat <<'EOF'
#compdef workshop-automated-installer.sh
_uws_workshop_complete() {
    local -a commands
    commands=(install init bootstrap launch refresh start stop restore remove list status info actions changes tasks warnings okay exec shell run ollama pull-model connections connect disconnect remount sdk sdk-find sdk-info sdk-list sdkcraft sdkcraft-install sdkcraft-refresh sketch-sdk sketches sketch-stash sketch-restore sketch-remove sketch-eject native workshop workshopctl version doctor completion ci)
    _describe 'command' commands
}
compdef _uws_workshop_complete workshop-automated-installer.sh
EOF
}

completion_fish() {
    cat <<'EOF'
set -l uws_commands install init bootstrap launch refresh start stop restore remove list status info actions changes tasks warnings okay exec shell run ollama pull-model connections connect disconnect remount sdk sdk-find sdk-info sdk-list sdkcraft sdkcraft-install sdkcraft-refresh sketch-sdk sketches sketch-stash sketch-restore sketch-remove sketch-eject native workshop workshopctl version doctor completion ci
complete -c workshop-automated-installer.sh -f -n '__fish_use_subcommand' -a "$uws_commands"
EOF
}

completion_powershell() {
    cat <<'EOF'
Register-ArgumentCompleter -CommandName workshop-automated-installer.sh -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commands = 'install','init','bootstrap','launch','refresh','start','stop','restore','remove','list','status','info','actions','changes','tasks','warnings','okay','exec','shell','run','ollama','pull-model','connections','connect','disconnect','remount','sdk','sdk-find','sdk-info','sdk-list','sdkcraft','sdkcraft-install','sdkcraft-refresh','sketch-sdk','sketches','sketch-stash','sketch-restore','sketch-remove','sketch-eject','native','workshop','workshopctl','version','doctor','completion','ci'
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
EOF
}

cmd_completion() {
    local shell_name=${1:-bash}
    (($# <= 1)) || die "completion accepts one shell name."
    case "$shell_name" in
        bash) completion_bash ;;
        zsh) completion_zsh ;;
        fish) completion_fish ;;
        powershell|pwsh) completion_powershell ;;
        *) die "Unsupported completion shell: ${shell_name}" ;;
    esac
}

cmd_ci() {
    local shell_file
    local -a shell_files=(
        "$SCRIPT_PATH"
        "$SCRIPT_DIR/tests/test-root-workshop-layout.sh"
        "$SCRIPT_DIR/tests/test-documentation-contract.sh"
        "$SCRIPT_DIR/tests/test-tutorial-fixtures.sh"
        "$SCRIPT_DIR/tests/test-workshop-automated-installer.sh"
        "$SCRIPT_DIR/ci/workshop-smoke.sh"
    )

    for shell_file in "${shell_files[@]}"; do
        [[ -f "$shell_file" ]] || continue
        bash -n "$shell_file"
    done

    if command -v shellcheck >/dev/null 2>&1; then
        shellcheck --shell=bash "${shell_files[@]}"
    elif [[ "${UWS_CI_REQUIRE_SHELLCHECK:-0}" == "1" ]]; then
        die "ShellCheck is required by UWS_CI_REQUIRE_SHELLCHECK=1 but is unavailable."
    else
        log "Warning: ShellCheck is unavailable; continuing with Bash syntax checks."
    fi

    "$SCRIPT_PATH" --help >/dev/null
    "$SCRIPT_PATH" --dry-run --project-dir "$SCRIPT_DIR/.ci-dry-run" init >/dev/null
    if [[ -f "$SCRIPT_DIR/tests/test-root-workshop-layout.sh" ]]; then
        bash "$SCRIPT_DIR/tests/test-root-workshop-layout.sh"
    fi
    if [[ -f "$SCRIPT_DIR/tests/test-documentation-contract.sh" ]]; then
        bash "$SCRIPT_DIR/tests/test-documentation-contract.sh"
    fi
    if [[ -f "$SCRIPT_DIR/tests/test-tutorial-fixtures.sh" ]]; then
        bash "$SCRIPT_DIR/tests/test-tutorial-fixtures.sh"
    fi
    if [[ -f "$SCRIPT_DIR/tests/test-workshop-automated-installer.sh" ]]; then
        bash "$SCRIPT_DIR/tests/test-workshop-automated-installer.sh"
    fi
    log "CI smoke checks passed without live snap/LXD mutation."
}

dispatch() {
    case "$COMMAND" in
        install) cmd_install "${COMMAND_ARGS[@]}" ;;
        init) cmd_init "${COMMAND_ARGS[@]}" ;;
        bootstrap) cmd_bootstrap "${COMMAND_ARGS[@]}" ;;
        launch|refresh|start|stop|restore) cmd_lifecycle "$COMMAND" "${COMMAND_ARGS[@]}" ;;
        remove) cmd_remove "${COMMAND_ARGS[@]}" ;;
        list|status) cmd_query list "${COMMAND_ARGS[@]}" ;;
        info|actions|connections) cmd_query "$COMMAND" "${COMMAND_ARGS[@]}" ;;
        changes|tasks|warnings|okay) cmd_query "$COMMAND" "${COMMAND_ARGS[@]}" ;;
        exec) cmd_exec "${COMMAND_ARGS[@]}" ;;
        shell) cmd_shell "${COMMAND_ARGS[@]}" ;;
        run) cmd_run "${COMMAND_ARGS[@]}" ;;
        ollama) cmd_ollama "${COMMAND_ARGS[@]}" ;;
        pull-model) cmd_pull_model "${COMMAND_ARGS[@]}" ;;
        connect|disconnect|remount) cmd_connectivity "$COMMAND" "${COMMAND_ARGS[@]}" ;;
        sketch-sdk) cmd_sketch_sdk "${COMMAND_ARGS[@]}" ;;
        sketches) run_project_workshop sketches "${COMMAND_ARGS[@]}" ;;
        sketch-stash) cmd_sketch_operation --stash "${COMMAND_ARGS[@]}" ;;
        sketch-restore) cmd_sketch_operation --restore "${COMMAND_ARGS[@]}" ;;
        sketch-remove) cmd_sketch_operation --remove "${COMMAND_ARGS[@]}" ;;
        sketch-eject) cmd_sketch_operation --eject "${COMMAND_ARGS[@]}" ;;
        sdk) run_tool sdk "${COMMAND_ARGS[@]}" ;;
        sdk-find) run_tool sdk find "${COMMAND_ARGS[@]}" ;;
        sdk-info) run_tool sdk info "${COMMAND_ARGS[@]}" ;;
        sdk-list) run_tool sdk list "${COMMAND_ARGS[@]}" ;;
        sdkcraft) run_project_tool sdkcraft "${COMMAND_ARGS[@]}" ;;
        sdkcraft-install) cmd_sdkcraft_install "${COMMAND_ARGS[@]}" ;;
        sdkcraft-refresh) cmd_sdkcraft_refresh "${COMMAND_ARGS[@]}" ;;
        native|workshop) cmd_native "${COMMAND_ARGS[@]}" ;;
        workshopctl) run_tool workshopctl "${COMMAND_ARGS[@]}" ;;
        version) run_tool workshop --version "${COMMAND_ARGS[@]}" ;;
        doctor) cmd_doctor "${COMMAND_ARGS[@]}" ;;
        completion) cmd_completion "${COMMAND_ARGS[@]}" ;;
        ci) cmd_ci "${COMMAND_ARGS[@]}" ;;
        help) usage ;;
        *) usage >&2; die "Unknown command: ${COMMAND}" ;;
    esac
}

main() {
    local dispatch_status=0

    find_config_path "$@"
    load_config_file
    parse_arguments "$@"
    validate_options
    if ((JSON_OUTPUT)) && ! json_command_supported; then
        die "--json is supported for query and diagnostic commands only."
    fi

    if [[ "$COMMAND" == "doctor" ]]; then
        dispatch
        dispatch_status=$DOCTOR_STATUS
    else
        dispatch
    fi
    if ((DRY_RUN)); then
        log "Dry run complete; no changes were made."
    fi
    exit "$dispatch_status"
}

main "$@"
