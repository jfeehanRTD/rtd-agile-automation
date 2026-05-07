#!/usr/bin/env bash
#
# bd-remote.sh — Run bd commands against the beads project directory
#
# Uses BEADS_PROJECT_DIR env var (set in ~/.zshrc) so you can run bd
# from this repo without cd-ing to the project repo.
#
# Usage:
#   ./scripts/bd-remote.sh jira sync --pull
#   ./scripts/bd-remote.sh list --status closed
#   ./scripts/bd-remote.sh ready
#
set -euo pipefail

PROJECT_DIR="${BEADS_PROJECT_DIR:?Set BEADS_PROJECT_DIR in ~/.zshrc (e.g. \~/projects/tisng/tis-next-gen)}"

(cd "$PROJECT_DIR" && bd "$@")
