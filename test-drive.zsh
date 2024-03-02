#!/usr/bin/env zsh

set -eu

TEST_ZDOTDIR="$(mktemp -d "${TMPDIR:-/tmp}/zshrc.XXXXXXXX")"
trap 'rm -rfv "$TEST_ZDOTDIR"' EXIT
export ZDOTDIR="$TEST_ZDOTDIR"
cp "${${0:A}:h}/zshrc" "$ZDOTDIR/.zshrc"

env zsh -idls
