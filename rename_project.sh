#!/bin/bash

set -euo pipefail

CURRENT_NAME="Windowpane"
CURRENT_OTP="windowpane"

NEW_NAME="Windowpane"
NEW_OTP="windowpane"

# sed -i usage for Ubuntu/Linux
SED_INPLACE_OPT=(-i)

# Replace in files (name + otp)
files=$(ack -l "$CURRENT_NAME" --ignore-file=is:rename_phoenix_project.sh || true)
if [ -n "$files" ]; then
  echo "$files" | xargs sed "${SED_INPLACE_OPT[@]}" "s/$CURRENT_NAME/$NEW_NAME/g"
fi

files=$(ack -l "$CURRENT_OTP" --ignore-file=is:rename_phoenix_project.sh || true)
if [ -n "$files" ]; then
  echo "$files" | xargs sed "${SED_INPLACE_OPT[@]}" "s/$CURRENT_OTP/$NEW_OTP/g"
fi

files=$(ack -l ":$CURRENT_OTP" --ignore-file=is:rename_phoenix_project.sh || true)
if [ -n "$files" ]; then
  echo "$files" | xargs sed "${SED_INPLACE_OPT[@]}" "s/:$CURRENT_OTP/:$NEW_OTP/g"
fi

# Rename folders and files
for path in \
  "lib/$CURRENT_OTP" \
  "lib/$CURRENT_OTP.ex" \
  "lib/${CURRENT_OTP}_web" \
  "lib/${CURRENT_OTP}_web.ex" \
  "test/$CURRENT_OTP" \
  "test/${CURRENT_OTP}_web"
do
  if [ -e "$path" ]; then
    new_path=$(echo "$path" | sed "s/$CURRENT_OTP/$NEW_OTP/g")
    git mv "$path" "$new_path"
  fi
done

# Rename any file or directory with CURRENT_OTP in its name (excluding _build/, deps/)
find . -depth \
  -not -path "./_build/*" \
  -not -path "./deps/*" \
  -name "*$CURRENT_OTP*" \
  ! -name "rename_phoenix_project.sh" | while read -r filepath; do

  newpath=$(echo "$filepath" | sed "s/$CURRENT_OTP/$NEW_OTP/g")
  if [ "$filepath" != "$newpath" ]; then
    # Use git mv if under git, else fallback to plain mv
    if git ls-files --error-unmatch "$filepath" > /dev/null 2>&1; then
      git mv "$filepath" "$newpath"
    else
      mv "$filepath" "$newpath"
    fi
  fi

done

echo "✅ Rename complete."
