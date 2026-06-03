#!/usr/bin/env bash
#
#  AnyDesk Block Remover  —  Linux
#  ----------------------------------------------------------------
#  Recovers a personal AnyDesk install from the free-tier
#  "commercial use suspected / session ended" block by resetting
#  the local AnyDesk ID, while preserving your saved PC IDs
#  (the address book / favorites stored in user.conf).
#
#  Repo:    https://github.com/trongio/anydesk_block_remove
#  License: MIT
#
set -euo pipefail

ASSUME_YES=0
NO_BACKUP=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)        ASSUME_YES=1 ;;
        --no-backup)     NO_BACKUP=1 ;;
    esac
done

# ----------------------------------------------------------------------
#  Colours / TUI helpers (disabled if not a TTY)
# ----------------------------------------------------------------------
if [ -t 1 ]; then
    CYAN=$'\033[38;5;45m'; GREEN=$'\033[38;5;82m'; YEL=$'\033[38;5;214m'
    DIM=$'\033[38;5;240m'; GREY=$'\033[38;5;250m'; RST=$'\033[0m'
else
    CYAN=''; GREEN=''; YEL=''; DIM=''; GREY=''; RST=''
fi

banner() {
    clear 2>/dev/null || true
    printf '\n'
    printf '%s    ___              ____            __  %s\n' "$CYAN" "$RST"
    printf '%s   /   |  ____  __  / __ \\___  _____/ /__%s\n' "$CYAN" "$RST"
    printf '%s  / /| | / __ \\/ / / / / / _ \\/ ___/ //_/%s\n' "$CYAN" "$RST"
    printf '%s / ___ |/ / / / /_/ / /_/ /  __(__  ) ,<  %s\n' "$CYAN" "$RST"
    printf '%s/_/  |_/_/ /_/\\__, /_____/\\___/____/_/|_| %s\n' "$CYAN" "$RST"
    printf '%s             /____/  BLOCK REMOVER%s\n' "$CYAN" "$RST"
    printf '\n'
    printf '%s  Resets your AnyDesk ID to lift the free-tier block.%s\n' "$DIM" "$RST"
    printf '%s  https://github.com/trongio/anydesk_block_remove%s\n' "$DIM" "$RST"
    printf '\n'
}

step()  { printf '  %s➜ %s%s\n' "$CYAN" "$RST" "$1"; }
ok()    { printf '    %s✔ %s%s%s\n' "$GREEN" "$GREY" "$1" "$RST"; }
warn()  { printf '    %s⚠ %s%s\n' "$YEL" "$1" "$RST"; }
skip()  { printf '    %s· %s%s\n' "$DIM" "$1" "$RST"; }
rule()  { printf '%s  --------------------------------------------------%s\n' "$DIM" "$RST"; }

# ----------------------------------------------------------------------
#  Require root
# ----------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    printf '\n  %sThis tool needs root. Re-run with sudo:%s\n' "$YEL" "$RST"
    printf '      sudo bash %s\n\n' "${BASH_SOURCE[0]:-fix-anydesk.sh}"
    exit 1
fi

# The user who invoked sudo (so we touch the right home directory).
REAL_USER="${SUDO_USER:-$(id -un)}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -z "$REAL_HOME" ] && REAL_HOME="$HOME"

banner

# Config locations on Linux.
CONF_DIRS=( "$REAL_HOME/.anydesk" "/etc/anydesk" "$REAL_HOME/.anydesk/global" )

# Files that hold machine identity / block state — safe to delete.
KILL_FILES=( "service.conf" "system.conf" "ad_svc.trace" "ad.trace" "connection_trace.txt" )

# Files we explicitly PRESERVE — these hold your saved PC IDs / favorites.
KEEP_FILES=( "user.conf" )

warn "Your saved PC IDs live in 'user.conf' (the address book / favorites)."
warn "This tool keeps that file, but a clean reset CANNOT BE GUARANTEED —"
warn "please note down any IDs/aliases you rely on before continuing."
printf '\n'

if [ "$ASSUME_YES" -ne 1 ]; then
    printf '  Proceed with the AnyDesk reset? [y/N] '
    read -r ans </dev/tty || ans=""
    case "$ans" in
        y|Y|yes|YES) ;;
        *) printf '%s\n  Cancelled. Nothing was changed.\n\n%s' "$DIM" "$RST"; exit 0 ;;
    esac
fi
printf '\n'; rule

# 1. Stop AnyDesk service + processes.
step "Stopping AnyDesk service and processes"
if command -v systemctl >/dev/null 2>&1; then
    if systemctl stop anydesk 2>/dev/null; then ok "Stopped anydesk.service"; else skip "No systemd anydesk.service"; fi
fi
if command -v anydesk >/dev/null 2>&1; then
    anydesk --stop-service >/dev/null 2>&1 || true
fi
if pkill -x anydesk 2>/dev/null; then ok "Closed running AnyDesk processes"; else skip "No running AnyDesk processes"; fi
sleep 1

# 2. Back up everything first (unless disabled).
if [ "$NO_BACKUP" -ne 1 ]; then
    STAMP="$(date +%Y%m%d-%H%M%S)"
    BACKUP_DIR="$REAL_HOME/anydesk-backup-$STAMP"
    step "Backing up current config to:"
    printf '%s      %s%s\n' "$DIM" "$BACKUP_DIR" "$RST"
    mkdir -p "$BACKUP_DIR"
    for d in "${CONF_DIRS[@]}"; do
        if [ -d "$d" ]; then
            cp -a "$d" "$BACKUP_DIR/$(echo "$d" | tr '/' '_')" 2>/dev/null || true
            ok "Backed up $d"
        fi
    done
    chown -R "$REAL_USER" "$BACKUP_DIR" 2>/dev/null || true
fi

# 3. Delete identity/block files, preserving the saved-IDs file.
step "Resetting AnyDesk identity (saved IDs preserved)"
deleted=0
for d in "${CONF_DIRS[@]}"; do
    [ -d "$d" ] || continue
    for f in "${KILL_FILES[@]}"; do
        if [ -f "$d/$f" ]; then
            rm -f "$d/$f" && ok "Removed $f  ($d)" && deleted=$((deleted+1))
        fi
    done
    for k in "${KEEP_FILES[@]}"; do
        [ -f "$d/$k" ] && skip "Kept $k  ($d)  <- your saved PC IDs"
    done
done
[ "$deleted" -eq 0 ] && warn "No identity files found — is AnyDesk installed?"

# 4. Restart the service so a fresh ID is generated.
step "Restarting AnyDesk service"
if command -v systemctl >/dev/null 2>&1; then
    systemctl start anydesk 2>/dev/null && ok "Started anydesk.service" || skip "Could not start service (start AnyDesk manually)"
fi

rule
printf '\n  %s✔ Done!%s\n' "$GREEN" "$RST"
printf '%s  Open AnyDesk — it should show a NEW ID and the block should be gone.%s\n' "$GREY" "$RST"
printf '%s  Your saved PC IDs (favorites) were left untouched.%s\n' "$GREY" "$RST"
[ "$NO_BACKUP" -ne 1 ] && printf '%s  A full backup was saved in your home folder if you need to restore.%s\n' "$DIM" "$RST"
printf '\n'
