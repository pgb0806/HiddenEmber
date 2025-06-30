#!/usr/bin/env bash

set -e

echo "⚔️  Installing required fonts for HiddenEmber"

mkdir -p fonts

# Anton
echo "🟢 Downloading Anton..."
curl -L -o fonts/Anton.ttf "https://github.com/google/fonts/raw/main/ofl/anton/Anton-Regular.ttf"

# Great Vibes
echo "🟢 Downloading Great Vibes..."
curl -L -o fonts/GreatVibes-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/greatvibes/GreatVibes-Regular.ttf"

# Oswald
echo "🟢 Downloading Oswald..."
curl -L -o fonts/Oswald-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/oswald/Oswald-Regular.ttf"

# Merriweather
echo "🟢 Downloading Merriweather..."
curl -L -o fonts/Merriweather-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/merriweather/Merriweather-Regular.ttf"

# Roboto Condensed
echo "🟢 Downloading Roboto Condensed..."
curl -L -o fonts/RobotoCondensed-Regular.ttf "https://github.com/google/fonts/raw/main/apache/robotocondensed/RobotoCondensed-Regular.ttf"

# Lora
echo "🟢 Downloading Lora..."
curl -L -o fonts/Lora-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/lora/Lora-Regular.ttf"

# Ubuntu
echo "🟢 Downloading Ubuntu..."
curl -L -o fonts/Ubuntu-Regular.ttf "https://github.com/google/fonts/raw/main/ubuntu/Ubuntu-Regular.ttf"

# Bebas Neue
echo "🟢 Downloading Bebas Neue..."
curl -L -o fonts/BebasNeue-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/bebasneue/BebasNeue-Regular.ttf"

# Pacifico
echo "🟢 Downloading Pacifico..."
curl -L -o fonts/Pacifico-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf"

echo "✅ All fonts downloaded to ./fonts"

