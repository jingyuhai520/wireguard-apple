#!/bin/bash
set -e
curl -Lo - https://crowdin.com/backend/download/project/wireguard.zip | bsdtar -C Sources/WireGuardApp -x -f - --strip-components 3 wireguard-apple
find Sources/WireGuardApp/*.lproj -type f -empty -delete
find Sources/WireGuardApp/*.lproj -type d -empty -delete
git add Sources/WireGuardApp/*.lproj

declare -A LOCALE_MAP
while read -r filename; do
	l="$(basename "$(dirname "$filename")" .lproj)"
	[[ $l == Base ]] && continue
	read -r -n 24 hex < <(LC_ALL=C tr -dc "A-F0-9" < /dev/urandom)
	LOCALE_MAP["$l"]="$hex"
done < <(find Sources/WireGuardApp -name Localizable.strings -type f)

inkr=0 inls=0 inlsc=0
while IFS= read -r line; do
	if [[ $line == *"name = Base; path = Sources/WireGuardApp/Base.lproj/Localizable.strings"* ]]; then
		echo "$line"
		for l in "${!LOCALE_MAP[@]}"; do
			printf '\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = %s; path = Sources/WireGuardApp/%s.lproj/Localizable.strings; sourceTree = "<group>"; };\n' "${LOCALE_MAP["$l"]}" "$l" "$l" "$l"
		done
	elif [[ $line == *"; path = Sources/WireGuardApp/"*".lproj/Localizable.strings"* ]]; then
		continue
	elif [[ $line == *"knownRegions = ("* ]]; then
		echo "$line"
		printf '\t\t\t\tBase,\n\t\t\t\ten,\n'
		for l in "${!LOCALE_MAP[@]}"; do
			printf '\t\t\t\t%s,\n' "$l"
		done
		inkr=1
	elif [[ $inkr -eq 1 && $line == *");"* ]]; then
		echo "$line"
		inkr=0
	elif [[ $inkr -eq 1 ]]; then
		continue
	elif [[ $inls -eq 0 && $line == *"/* Localizable.strings */ = {"* ]]; then
		echo "$line"
		inls=1
	elif [[ $inls -eq 1 && $inlsc -eq 0 && $line == *"children = ("* ]]; then
		echo "$line"
		inlsc=1
		for l in "${!LOCALE_MAP[@]}"; do
			printf '\t\t\t\t%s /* %s */,\n' "${LOCALE_MAP["$l"]}" "$l"
		done
	elif [[ $inls -eq 1 && $inlsc -eq 1 && $line == *");"* ]]; then
		echo "$line"
		inlsc=0
	elif [[ $inls -eq 1 && $inlsc -eq 0 && $line == *"};"* ]]; then
		echo "$line"
		inls=0
	elif [[ $inls -eq 1 && $inlsc -eq 1 && $line != *" Base "* ]]; then
		continue
	else
		echo "$line"
	fi
done < WireGuard.xcodeproj/project.pbxproj > WireGuard.xcodeproj/project.pbxproj.new
mv WireGuard.xcodeproj/project.pbxproj.new WireGuard.xcodeproj/project.pbxproj
git add WireGuard.xcodeproj/project.pbxproj
