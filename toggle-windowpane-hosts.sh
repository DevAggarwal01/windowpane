#!/bin/bash

# Target line (must match exactly)
TARGET_LINE="127.0.0.1 windowpane.tv studio.windowpane.tv admin.windowpane.tv"
HOSTS_FILE="/etc/hosts"

# Backup the original hosts file
echo "📦 Backing up /etc/hosts to /etc/hosts.bak"
sudo cp "$HOSTS_FILE" "$HOSTS_FILE.bak"

# Check if the line is currently commented out
if grep -qE "^\s*#\s*$TARGET_LINE" "$HOSTS_FILE"; then
  echo "🔁 Un-commenting the line..."
  sudo sed -i "s|^\s*#\s*$TARGET_LINE|$TARGET_LINE|" "$HOSTS_FILE"
else
  echo "🔁 Commenting the line..."
  sudo sed -i "s|^\s*$TARGET_LINE|# $TARGET_LINE|" "$HOSTS_FILE"
fi

echo "✅ Toggled the /etc/hosts entry for windowpane.tv"

