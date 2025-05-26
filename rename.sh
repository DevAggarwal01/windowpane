#!/bin/bash

set -e

CURRENT_NAME="Aurora"       # Module name
CURRENT_OTP="aurora"        # OTP app name (used in paths)

NEW_NAME="Nova"
NEW_OTP="nova"

# Replace module name (case-sensitive)
ack -l "$CURRENT_NAME" | xargs sed -i '' -e "s/\b$CURRENT_NAME\b/$NEW_NAME/g"

# Replace OTP app name (lowercase, also paths)
ack -l "$CURRENT_OTP" | xargs sed -i '' -e "s/\b$CURRENT_OTP\b/$NEW_OTP/g"

# Rename lib dirs and main app files
mv lib/$CURRENT_OTP lib/$NEW_OTP
mv lib/$CURRENT_OTP.ex lib/$NEW_OTP.ex

mv lib/${CURRENT_OTP}_web lib/${NEW_OTP}_web
mv lib/${CURRENT_OTP}_web.ex lib/${NEW_OTP}_web.ex
	
