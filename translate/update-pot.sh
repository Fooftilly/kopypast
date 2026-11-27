#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

namespace="io.github.fooftilly.kopypast"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

echo "Extracting translatable strings..."
xgettext --from-code=UTF-8 \
         --output="$staging/kopypast.pot" \
         --package-name=Kopypast \
         --copyright-holder="Vladimir Kosolapov" \
         --msgid-bugs-address="https://github.com/Fooftilly/kopypast/issues" \
         --add-location=file \
         --keyword=i18n:1 \
         --keyword=i18nc:1c,2 \
         --keyword=i18np:1,2 \
         --keyword=i18ncp:1c,2,3 \
         --keyword=ki18n:1 \
         --keyword=ki18nc:1c,2 \
         --keyword=ki18np:1,2 \
         --keyword=ki18ncp:1c,2,3 \
         package/contents/**/*.qml

echo "Compiling translation files..."
shopt -s nullglob
po_files=(translate/*.po)
for po_file in "${po_files[@]}"; do
    lang=$(basename "$po_file" .po)
    echo "Compiling $lang"
    msgfmt --check-format -o "$staging/$lang.mo" "$po_file"
done

# Publish only after all extraction and compilation commands succeed.
install -m 644 "$staging/kopypast.pot" translate/kopypast.pot
for po_file in "${po_files[@]}"; do
    lang=$(basename "$po_file" .po)
    locale_dir="package/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$locale_dir"
    install -m 644 "$staging/$lang.mo" "$locale_dir/plasma_applet_$namespace.mo"
done

echo "Translations processing completed. Compiled: ${#po_files[@]}"
