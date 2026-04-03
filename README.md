qmail-ssh-relay
===============
This script sets up a mechanism to relay mails for root to a remote machine using qmail dot files and an SSH connection.

Usage
-----
Run `./setup.sh receive-host` on the FreeBSD host.

When prompted, paste one trusted `known_hosts` line for the remote host. You can obtain one from a trusted system using `ssh-keyscan -t ssh-ed25519 <hostname>` or a similar command. If the input is empty, the script warns and falls back to fetching the host key on first connection.

The script avoids duplicate `.qmail-root` entries when re-run.
