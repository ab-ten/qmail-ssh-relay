#!/bin/sh

set -eu

aliasuser="${aliasuser:-alias}"
aliasdir="${aliasdir:-/var/qmail/alias}"
identity="${identity:-${aliasdir}/.ssh/id_qmail_ssh_relay}"
receiveuser="${receiveuser:-ssh-mail-relay}"
knownhosts_entry="${knownhosts_entry:-}"

usage() {
    echo "usage: $0 receive-host" >&2
    exit 1
}

die() {
    echo "$*" >&2
    exit 1
}

warn() {
    echo "warning: $*" >&2
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "command not found: $1"
}

append_unique_line() {
    file_path="$1"
    line="$2"

    if [ -f "$file_path" ] && grep -Fqx "$line" "$file_path"; then
        return 0
    fi

    printf '%s\n' "$line" >>"$file_path"
}

ensure_owner() {
    path="$1"
    owner="$2"
    actual_owner=$(stat -f "%Su" "$path")
    [ "$actual_owner" = "$owner" ] || die "$path owner is not $owner"
}

prompt_known_hosts_entry() {
    if [ -n "$knownhosts_entry" ]; then
        return 0
    fi

    if [ -t 0 ]; then
        echo "Paste a trusted known_hosts line for $receivehost, or press Enter to fetch it from the server:"
        IFS= read -r knownhosts_entry || true
    fi
}

fetch_known_hosts() {
    warn "known_hosts entry is empty. Falling back to fetching the host key from $receivehost on first connection."
    su -m "$aliasuser" -c "/usr/bin/ssh -i \"$identity\" -o \"UserKnownHostsFile=$known_hosts_file\" -o StrictHostKeyChecking=no \"$receiveuser@$receivehost\" true"
}

if [ "$#" -ne 1 ]; then
    usage
fi
receivehost="$1"

require_command pw
require_command stat
require_command mkdir
require_command chown
require_command chmod
require_command su
require_command ssh
require_command ssh-keygen
require_command grep
require_command hostname
require_command cat

pw usershow "$aliasuser" >/dev/null 2>&1 || die "user $aliasuser not found, install qmail."
[ -d "$aliasdir" ] || die "no $aliasdir, install qmail."

sshdir="${aliasdir}/.ssh"
known_hosts_file="${sshdir}/known_hosts"
qmail_root="${aliasdir}/.qmail-root"
relay_command="|/usr/bin/ssh -i \"$identity\" -o \"UserKnownHostsFile=$known_hosts_file\" \"$receiveuser@$receivehost\" || exit 111"

umask 077

if [ ! -d "$sshdir" ]; then
    mkdir -m 700 "$sshdir"
    chown "$aliasuser" "$sshdir"
else
    ensure_owner "$sshdir" "$aliasuser"
    chmod 700 "$sshdir"
fi

if [ ! -f "$identity" ]; then
    su -m "$aliasuser" -c "ssh-keygen -f \"$identity\" -N '' -C qmail-ssh-relay"
else
    echo "$identity already exists."
fi

if [ ! -f "$known_hosts_file" ]; then
    : >"$known_hosts_file"
    chown "$aliasuser" "$known_hosts_file"
    chmod 600 "$known_hosts_file"
else
    ensure_owner "$known_hosts_file" "$aliasuser"
    chmod 600 "$known_hosts_file"
fi

prompt_known_hosts_entry

if [ -n "$knownhosts_entry" ]; then
    append_unique_line "$known_hosts_file" "$knownhosts_entry"
else
    fetch_known_hosts
fi

if [ ! -f "$qmail_root" ]; then
    : >"$qmail_root"
fi
append_unique_line "$qmail_root" "$relay_command"

echo ""
echo "$qmail_root is now,"
cat "$qmail_root"

echo ""
echo "known_hosts is now,"
cat "$known_hosts_file"

echo ""
echo "append below to ~${receiveuser}/.ssh/authorized_keys on ${receivehost}"
echo ""
localhostname=$(hostname)
printf 'from="%s",command="/usr/sbin/sendmail root" ' "$localhostname"
cat "${identity}.pub"
