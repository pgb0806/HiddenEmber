#!/usr/bin/env bash
set -e

echo "⚔️ TESTING WISDOM SHORTS LOCALLY WITH DYNAMIC FONT + SMART STACK + CLEAN TEMP"

# 1️⃣ Pick mood
MOODS=("Resolute")
MOOD="${MOODS[$((RANDOM % ${#MOODS[@]}))]}"
echo "🟢 Mood chosen: $MOOD"

# random Drive IDs from urls.txt
VIDEO_ID=$(shuf -n1 assets/$MOOD/background/urls.txt)
MUSIC_ID=$(shuf -n1 assets/$MOOD/music/urls.txt)

# download
gdown --fuzzy "https://drive.google.com/uc?id=$VIDEO_ID" -O video.mp4
gdown --fuzzy "https://drive.google.com/uc?id=$MUSIC_ID" -O music.wav

VIDEO="video.mp4"
MUSIC="music.wav"

# 2️⃣ Font and colors
if [ ! -f mood_rules.json ]; then
  FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
  COLOR="white"
  BOXCOLOR="black@0.7"
else
  RULES=$(jq -c --arg mood "$MOOD" '.[$mood]' mood_rules.json)
  FONT=$(echo "$RULES" | jq -r '.font // "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"')
  COLOR=$(echo "$RULES" | jq -r '.fontColor // "white"')
  BOXCOLOR="black@0.7"
fi

# 3️⃣ Hook
HOOKS=(
  "They never taught you this…"
  "Read this before you decide…"
  "Most people get this wrong…"
  "Break this rule to win…"
  "Before you act, hear this…"
)
HOOK="${HOOKS[$((RANDOM % ${#HOOKS[@]}))]}"
echo "$HOOK" > hook.txt
echo "🟢 Hook chosen: $HOOK"

# 4️⃣ Load JSON
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

# 5️⃣ Chunk splitting
CHUNKS=()
while read -r line; do
  CHUNKS+=("$line")
done < <(echo "$TEXT" | fold -s -w 40)

CHUNK_COUNT=${#CHUNKS[@]}
echo "🟢 Found $CHUNK_COUNT chunks"

# 6️⃣ Timing
INTRO_DURATION=2
PAUSE_AFTER=0.5
FADEIN=0.5
HOLD=3
FADEOUT=0.5

STARTS=()
start=$INTRO_DURATION
for ((i=0; i<CHUNK_COUNT; i++)); do
  STARTS+=($start)
  start=$(echo "$start + $FADEIN + $HOLD + $FADEOUT + $PAUSE_AFTER" | bc)
done
FINAL_DURATION=$(echo "${STARTS[-1]} + $FADEIN + $HOLD + $FADEOUT + 3" | bc)

# 7️⃣ Eye placement
HOOK_Y="(h/6 - text_h/2)"
OUTRO_Y="(h*5/6 - text_h/2)"
WATERMARK_Y="40"
CTA_Y="40"

# 8️⃣ Concat if video is too short
VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO")
if (( $(echo "$VIDEO_DURATION < $FINAL_DURATION" | bc -l) )); then
  SECOND_VIDEO_ID=$(shuf -n1 assets/$MOOD/background/urls.txt)
  gdown --fuzzy "https://drive.google.com/uc?id=$SECOND_VIDEO_ID" -O second_video.mp4
  echo -e "file '$VIDEO'\nfile 'second_video.mp4'" > concatlist.txt
  ffmpeg -hide_banner -y -f concat -safe 0 -i concatlist.txt -c copy temp_combined.mp4
  VIDEO="temp_combined.mp4"
  echo "🟢 Added second segment to match video length"
fi

# 9️⃣ Dynamic chunk stacking + font scaling
DRAW_TEXTS="drawtext=textfile='hook.txt':fontfile=$FONT:fontsize=64:fontcolor=$COLOR:box=1:boxcolor=$BOXCOLOR:boxborderw=12:x=(w-text_w)/2:y=$HOOK_Y:enable='between(t,0,$FINAL_DURATION)',"

for ((i=0; i<CHUNK_COUNT; i++)); do
  # dynamic font based on chunk length
  LEN=${#CHUNKS[i]}
  if (( LEN < 20 )); then
    CHUNK_FONT=56
  elif (( LEN < 40 )); then
    CHUNK_FONT=48
  else
    CHUNK_FONT=42
  fi
  chunk_y="(h/3 + ${i}*60)"
  DRAW_TEXTS+="drawtext=text='${CHUNKS[i]}':fontfile=$FONT:fontsize=$CHUNK_FONT:fontcolor=$COLOR:x=(w-text_w)/2:y=$chunk_y:enable='gte(t,${STARTS[i]})':box=1:boxcolor=$BOXCOLOR:boxborderw=10,"
done

#  🔟 author + outro
if [[ -n "$AUTHOR_AND_REF" ]]; then
  DRAW_TEXTS+="drawtext=text='$AUTHOR_AND_REF':fontfile=$FONT:fontsize=36:fontcolor=$COLOR:x=(w-text_w)/2:y=(h*4/5 - text_h/2):enable='between(t,$INTRO_DURATION,$FINAL_DURATION)',"
fi

DRAW_TEXTS+="drawtext=text='Follow for daily wisdom @HiddenEmber-v3p':fontfile=$FONT:fontsize=42:fontcolor=$COLOR:box=1:boxcolor=$BOXCOLOR:boxborderw=10:x=(w-text_w)/2:y=$OUTRO_Y:enable='between(t,${FINAL_DURATION}-3,$FINAL_DURATION)',"
DRAW_TEXTS+="drawtext=text='@HiddenEmber-v3p':fontfile=$FONT:fontsize=24:fontcolor=white@0.7:x=w-tw-30:y=$WATERMARK_Y:enable='between(t,0,$FINAL_DURATION)',"
DRAW_TEXTS+="drawtext=text='Double tap if you agree':fontfile=$FONT:fontsize=28:fontcolor=white@0.9:x=30:y=$CTA_Y:enable='between(t,$INTRO_DURATION,$FINAL_DURATION)'"

# 🔄 scaling
SCALE="scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920"
FILTER_COMPLEX="[0:v]$SCALE,$DRAW_TEXTS[v]"

# 🔊 Audio
HAS_AUDIO=$(ffprobe -loglevel error -select_streams a -show_entries stream=index -of csv=p=0 "$VIDEO" | wc -l)
if [ "$HAS_AUDIO" -eq 0 ]; then
  ffmpeg -hide_banner -y \
    -i "$VIDEO" -i "$MUSIC" \
    -filter_complex "$FILTER_COMPLEX" \
    -map "[v]" -map 1:a \
    -t "$FINAL_DURATION" \
    -c:v libx264 -c:a aac \
    final.mp4
else
  ffmpeg -hide_banner -y \
    -i "$VIDEO" -i "$MUSIC" \
    -filter_complex "$FILTER_COMPLEX;[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=2[a]" \
    -map "[v]" -map "[a]" \
    -t "$FINAL_DURATION" \
    -c:v libx264 -c:a aac \
    final.mp4
fi

# 🧹 Clean-up
rm -f second_video.mp4 concatlist.txt hook.txt video.mp4 music.wav temp_combined.mp4 || true
echo "🟢 Clean-up done."

echo "✅ Empire-grade wisdom video done with dynamic font, stacked text, and clean file hygiene."
echo "▶️ Play with: ffplay final.mp4"
