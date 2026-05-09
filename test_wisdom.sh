#!/usr/bin/env bash
set -euo pipefail

echo "⚔️ TESTING WISDOM SHORTS LOCALLY WITH DYNAMIC FONT + SMART STACK + CLEAN TEMP"

# --------------------------------------------------
# 1️⃣ Pick mood
# --------------------------------------------------

MOODS=("Resolute")
MOOD="${MOODS[$((RANDOM % ${#MOODS[@]}))]}"

echo "🟢 Mood chosen: $MOOD"

# --------------------------------------------------
# 2️⃣ Pick random asset IDs
# urls.txt MUST contain ONLY Google Drive file IDs
# --------------------------------------------------

VIDEO_ID=$(shuf -n1 "assets/$MOOD/background/urls.txt")
MUSIC_ID=$(shuf -n1 "assets/$MOOD/music/urls.txt")

echo "🟢 Downloading assets..."

# modern gdown usage (no --fuzzy)
gdown "$VIDEO_ID" -O video.mp4
gdown "$MUSIC_ID" -O music.wav

VIDEO="video.mp4"
MUSIC="music.wav"

# --------------------------------------------------
# 3️⃣ Font and colors
# --------------------------------------------------

DEFAULT_FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

if [ ! -f mood_rules.json ]; then
  FONT="$DEFAULT_FONT"
  COLOR="white"
  BOXCOLOR="black@0.7"
else
  RULES=$(jq -c --arg mood "$MOOD" '.[$mood]' mood_rules.json)

  FONT=$(echo "$RULES" | jq -r '.font // empty')
  COLOR=$(echo "$RULES" | jq -r '.fontColor // "white"')

  [ -z "$FONT" ] && FONT="$DEFAULT_FONT"

  BOXCOLOR="black@0.7"
fi

echo "🟢 Using font: $FONT"

# --------------------------------------------------
# 4️⃣ Hook
# --------------------------------------------------

HOOKS=(
  "They never taught you this..."
  "Read this before you decide..."
  "Most people get this wrong..."
  "Break this rule to win..."
  "Before you act, hear this..."
)

HOOK="${HOOKS[$((RANDOM % ${#HOOKS[@]}))]}"

echo "$HOOK" > hook.txt

echo "🟢 Hook chosen: $HOOK"

# --------------------------------------------------
# 5️⃣ Load JSON input
# --------------------------------------------------

INPUT_JSON="input.json"

TEXT=$(jq -r '.text' "$INPUT_JSON")
AUTHOR=$(jq -r '.author // empty' "$INPUT_JSON")
REFERENCE=$(jq -r '.reference // empty' "$INPUT_JSON")

if [[ -n "$AUTHOR" && -n "$REFERENCE" ]]; then
  AUTHOR_AND_REF="$AUTHOR, $REFERENCE"
elif [[ -n "$AUTHOR" ]]; then
  AUTHOR_AND_REF="$AUTHOR"
elif [[ -n "$REFERENCE" ]]; then
  AUTHOR_AND_REF="$REFERENCE"
else
  AUTHOR_AND_REF=""
fi

echo "🟢 Final text: $TEXT"

# --------------------------------------------------
# 6️⃣ Chunk splitting
# --------------------------------------------------

CHUNKS=()

while read -r line; do
  CHUNKS+=("$line")
done < <(echo "$TEXT" | fold -s -w 40)

CHUNK_COUNT=${#CHUNKS[@]}

echo "🟢 Found $CHUNK_COUNT chunks"

# --------------------------------------------------
# 7️⃣ Timing
# --------------------------------------------------

INTRO_DURATION=2
PAUSE_AFTER=0.5
FADEIN=0.5
HOLD=3
FADEOUT=0.5

STARTS=()

start=$INTRO_DURATION

for ((i=0; i<CHUNK_COUNT; i++)); do
  STARTS+=("$start")
  start=$(echo "$start + $FADEIN + $HOLD + $FADEOUT + $PAUSE_AFTER" | bc)
done

LAST_INDEX=$((CHUNK_COUNT - 1))

FINAL_DURATION=$(echo "${STARTS[$LAST_INDEX]} + $FADEIN + $HOLD + $FADEOUT + 3" | bc)

echo "🟢 Final duration: $FINAL_DURATION"

# --------------------------------------------------
# 8️⃣ Eye placement
# --------------------------------------------------

HOOK_Y="(h/6 - text_h/2)"
OUTRO_Y="(h*5/6 - text_h/2)"
WATERMARK_Y="40"
CTA_Y="40"

# --------------------------------------------------
# 9️⃣ Extend video if too short
# --------------------------------------------------

VIDEO_DURATION=$(ffprobe \
  -v error \
  -show_entries format=duration \
  -of csv=p=0 \
  "$VIDEO")

if (( $(echo "$VIDEO_DURATION < $FINAL_DURATION" | bc -l) )); then

  echo "🟡 Video too short. Adding second clip..."

  SECOND_VIDEO_ID=$(shuf -n1 "assets/$MOOD/background/urls.txt")

  gdown "$SECOND_VIDEO_ID" -O second_video.mp4

  echo -e "file 'video.mp4'\nfile 'second_video.mp4'" > concatlist.txt

  ffmpeg -hide_banner -y \
    -f concat \
    -safe 0 \
    -i concatlist.txt \
    -c copy \
    temp_combined.mp4

  VIDEO="temp_combined.mp4"

  echo "🟢 Added second segment"
fi

# --------------------------------------------------
# 🔟 Prepare text safely
# --------------------------------------------------

escape_ffmpeg_text() {
  echo "$1" | sed \
    -e "s/'/\\\\\\\\'/g" \
    -e 's/:/\\:/g'
}

# --------------------------------------------------
# 1️⃣1️⃣ Build drawtext filters
# --------------------------------------------------

DRAW_TEXTS=""

# hook
DRAW_TEXTS+="drawtext=textfile='hook.txt':"
DRAW_TEXTS+="fontfile=$FONT:"
DRAW_TEXTS+="fontsize=64:"
DRAW_TEXTS+="fontcolor=$COLOR:"
DRAW_TEXTS+="box=1:"
DRAW_TEXTS+="boxcolor=$BOXCOLOR:"
DRAW_TEXTS+="boxborderw=12:"
DRAW_TEXTS+="x=(w-text_w)/2:"
DRAW_TEXTS+="y=$HOOK_Y:"
DRAW_TEXTS+="enable='between(t,0,$FINAL_DURATION)',"

# chunks
for ((i=0; i<CHUNK_COUNT; i++)); do

  LEN=${#CHUNKS[i]}

  if (( LEN < 20 )); then
    CHUNK_FONT=56
  elif (( LEN < 40 )); then
    CHUNK_FONT=48
  else
    CHUNK_FONT=42
  fi

  chunk_y="(h/3 + ${i}*60)"

  SAFE_TEXT=$(escape_ffmpeg_text "${CHUNKS[i]}")

  DRAW_TEXTS+="drawtext=text='$SAFE_TEXT':"
  DRAW_TEXTS+="fontfile=$FONT:"
  DRAW_TEXTS+="fontsize=$CHUNK_FONT:"
  DRAW_TEXTS+="fontcolor=$COLOR:"
  DRAW_TEXTS+="x=(w-text_w)/2:"
  DRAW_TEXTS+="y=$chunk_y:"
  DRAW_TEXTS+="enable='gte(t,${STARTS[i]})':"
  DRAW_TEXTS+="box=1:"
  DRAW_TEXTS+="boxcolor=$BOXCOLOR:"
  DRAW_TEXTS+="boxborderw=10,"
done

# author
if [[ -n "$AUTHOR_AND_REF" ]]; then

  SAFE_AUTHOR=$(escape_ffmpeg_text "$AUTHOR_AND_REF")

  DRAW_TEXTS+="drawtext=text='$SAFE_AUTHOR':"
  DRAW_TEXTS+="fontfile=$FONT:"
  DRAW_TEXTS+="fontsize=36:"
  DRAW_TEXTS+="fontcolor=$COLOR:"
  DRAW_TEXTS+="x=(w-text_w)/2:"
  DRAW_TEXTS+="y=(h*4/5 - text_h/2):"
  DRAW_TEXTS+="enable='between(t,$INTRO_DURATION,$FINAL_DURATION)',"
fi

# outro
OUTRO_TEXT="Follow for daily wisdom @HiddenEmber-v3p"
SAFE_OUTRO=$(escape_ffmpeg_text "$OUTRO_TEXT")

DRAW_TEXTS+="drawtext=text='$SAFE_OUTRO':"
DRAW_TEXTS+="fontfile=$FONT:"
DRAW_TEXTS+="fontsize=42:"
DRAW_TEXTS+="fontcolor=$COLOR:"
DRAW_TEXTS+="box=1:"
DRAW_TEXTS+="boxcolor=$BOXCOLOR:"
DRAW_TEXTS+="boxborderw=10:"
DRAW_TEXTS+="x=(w-text_w)/2:"
DRAW_TEXTS+="y=$OUTRO_Y:"
DRAW_TEXTS+="enable='between(t,${FINAL_DURATION}-3,$FINAL_DURATION)',"

# watermark
DRAW_TEXTS+="drawtext=text='@HiddenEmber-v3p':"
DRAW_TEXTS+="fontfile=$FONT:"
DRAW_TEXTS+="fontsize=24:"
DRAW_TEXTS+="fontcolor=white@0.7:"
DRAW_TEXTS+="x=w-tw-30:"
DRAW_TEXTS+="y=$WATERMARK_Y:"
DRAW_TEXTS+="enable='between(t,0,$FINAL_DURATION)',"

# CTA
CTA_TEXT="Double tap if you agree"
SAFE_CTA=$(escape_ffmpeg_text "$CTA_TEXT")

DRAW_TEXTS+="drawtext=text='$SAFE_CTA':"
DRAW_TEXTS+="fontfile=$FONT:"
DRAW_TEXTS+="fontsize=28:"
DRAW_TEXTS+="fontcolor=white@0.9:"
DRAW_TEXTS+="x=30:"
DRAW_TEXTS+="y=$CTA_Y:"
DRAW_TEXTS+="enable='between(t,$INTRO_DURATION,$FINAL_DURATION)'"

# --------------------------------------------------
# 1️⃣2️⃣ Scaling
# --------------------------------------------------

SCALE="scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920"

FILTER_COMPLEX="[0:v]$SCALE,$DRAW_TEXTS[v]"

# --------------------------------------------------
# 1️⃣3️⃣ Audio handling
# --------------------------------------------------

HAS_AUDIO=$(ffprobe \
  -loglevel error \
  -select_streams a \
  -show_entries stream=index \
  -of csv=p=0 \
  "$VIDEO" | wc -l)

echo "🟢 Rendering final video..."

if [ "$HAS_AUDIO" -eq 0 ]; then

  ffmpeg -hide_banner -y \
    -i "$VIDEO" \
    -i "$MUSIC" \
    -filter_complex "$FILTER_COMPLEX" \
    -map "[v]" \
    -map 1:a \
    -t "$FINAL_DURATION" \
    -c:v libx264 \
    -preset medium \
    -crf 23 \
    -c:a aac \
    -shortest \
    final.mp4

else

  ffmpeg -hide_banner -y \
    -i "$VIDEO" \
    -i "$MUSIC" \
    -filter_complex "$FILTER_COMPLEX;[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=2[a]" \
    -map "[v]" \
    -map "[a]" \
    -t "$FINAL_DURATION" \
    -c:v libx264 \
    -preset medium \
    -crf 23 \
    -c:a aac \
    -shortest \
    final.mp4
fi

# --------------------------------------------------
# 1️⃣4️⃣ Cleanup
# --------------------------------------------------

rm -f \
  second_video.mp4 \
  concatlist.txt \
  hook.txt \
  video.mp4 \
  music.wav \
  temp_combined.mp4 || true

echo "🟢 Clean-up done."

# --------------------------------------------------
# ✅ Finished
# --------------------------------------------------

echo "✅ Empire-grade wisdom video done with dynamic font, stacked text, and clean file hygiene."
echo "▶️ Play with: ffplay final.mp4"