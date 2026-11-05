#!/usr/bin/env bash
# Dev-only: vendors mrml's MJML fixtures into test/fixtures/corpus/.
#
# Usage: spec_gen/sync_corpus.sh [mrml git tag]   (default: mrml-v6.0.1)
#
# Copies the .mjml files from packages/mrml-core/resources/compare/success/ and
# packages/mrml-core/resources/template/, plus mrml's LICENSE, and records the
# tag and commit in test/fixtures/corpus/SOURCE. Only the .mjml files are
# vendored: the tests compare against mjml_nif's output, generated on the fly.

set -euo pipefail

tag="${1:-mrml-v6.0.1}"
repo="https://github.com/jdrouet/mrml"
root="$(cd "$(dirname "$0")/.." && pwd)"
corpus="$root/test/fixtures/corpus"
checkout="$(mktemp -d)"
trap 'rm -rf "$checkout"' EXIT

git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$tag" "$repo" "$checkout"
commit="$(git -C "$checkout" rev-parse HEAD)"
resources="$checkout/packages/mrml-core/resources"

rm -rf "$corpus/compare" "$corpus/template"
mkdir -p "$corpus/compare" "$corpus/template"
cp "$resources"/compare/success/*.mjml "$corpus/compare/"
cp "$resources"/template/*.mjml "$corpus/template/"
cp "$checkout/LICENSE" "$corpus/LICENSE"

printf 'repo: %s\ntag: %s\ncommit: %s\n' "$repo" "$tag" "$commit" > "$corpus/SOURCE"

echo "Vendored $(ls "$corpus/compare" | wc -l | tr -d ' ') component fixtures and $(ls "$corpus/template" | wc -l | tr -d ' ') templates from $tag ($commit)"
