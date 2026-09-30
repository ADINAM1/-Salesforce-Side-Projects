#!/usr/bin/env bash
# Rebuilds dist/enrollment-portfolio-deploy.zip: the Metadata API format zip (package.xml at the root)
# used to deploy through Workbench without the CLI. Re-run after changing anything in force-app.
# Requires the Salesforce CLI (sf) and zip.
# Run: ./scripts/build-deploy-zip.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$root"
sf project convert source --manifest manifest/package.xml --output-dir "$work/mdapi"

mkdir -p dist
rm -f dist/enrollment-portfolio-deploy.zip
(cd "$work/mdapi" && zip -rqX "$root/dist/enrollment-portfolio-deploy.zip" .)
echo "Wrote dist/enrollment-portfolio-deploy.zip"
