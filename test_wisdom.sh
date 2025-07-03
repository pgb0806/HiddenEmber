#!/usr/bin/env bash
set -e

echo "⚔️ TESTING WISDOM SHORTS LOCALLY WITH DYNAMIC CHUNKS + SMART VIDEO CONCAT + POWERFUL HOOK + CONSISTENT BOXCOLOR"

# 1️⃣ Pick mood (could expand later with more)
MOODS=("Resolute")
MOOD="${MOODS[$((RANDOM % ${#MOODS[@]}))]}"
echo "🟢 Mood chosen: $MOOD"

# pick a random Drive file ID from urls.txt
VIDEO_ID=$(shuf -n1 assets/$MOOD/background/urls.txt)
MUSIC_ID=$(shuf -n1 assets/$MOOD/music/urls.txt)

# download from Drive with gdown
gdown --fuzzy "https://drive.google.com/uc?id=$VIDEO_ID" -O video.mp4
gdown --fuzzy "https://drive.google.com/uc?id=$MUSIC_ID" -O music.wav

VIDEO="video.mp4"
MUSIC="music.wav"


echo "🟢 Video chosen: $VIDEO"
echo "🟢 Music chosen: $MUSIC"

# 3️⃣ Load font and colors (fallback to defaults)
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

# 4️⃣ Hooks
HOOKS=(
  "They never taught you this…"
  "Read this before you decide…"
  "Most people get this wrong…"
  "Here’s what nobody tells you…"
  "Break this rule to win…"
  "Before you act, hear this…"
)
HOOK="${HOOKS[$((RANDOM % ${#HOOKS[@]}))]}"
echo "$HOOK" > hook.txt
echo "🟢 Hook chosen: $HOOK"

# 5️⃣ Load content from input.json
INPUT_JSON="input.json"

TEXT=$(jq -r '.text' "$INPUT_JSON")
AUTHOR=$(jq -r '.author // empty' "$INPUT_JSON")
REFERENCE=$(jq -r '.reference // empty' "$INPUT_JSON")

if [[ -n "$AUTHOR" && -n "$REFERENCE" ]]; then
  TEXT="$TEXT - $AUTHOR, $REFERENCE"
elif [[ -n "$AUTHOR" ]]; then
  TEXT="$TEXT - $AUTHOR"
elif [[ -n "$REFERENCE" ]]; then
  TEXT="$TEXT - $REFERENCE"
fi

echo "🟢 Final text for video: $TEXT"

# 6️⃣ Chunk split for animation
CHUNKS=()
while read -r line; do
  CHUNKS+=("$line")
done < <(echo "$TEXT" | fold -s -w 40)

CHUNK_COUNT=${#CHUNKS[@]}
echo "🟢 Detected $CHUNK_COUNT text chunks"

# 7️⃣ Timing setup
INTRO="hook.txt"
OUTRO="Follow for daily wisdom @HiddenEmber-v3p"
WATERMARK="@HiddenEmber-v3p"
CTA="Double tap if you agree"

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
echo "🟢 Final calculated duration: $FINAL_DURATION sec"

# 8️⃣ Handle too-short video
VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO")
if (( $(echo "$VIDEO_DURATION < $FINAL_DURATION" | bc -l) )); then
  echo "⚠️ Video too short, combining with another random"
  SECOND_VIDEO=$(shuf -n1 assets/$MOOD/background/urls.txt)
  gdown --fuzzy "https://drive.google.com/uc?id=$SECOND_VIDEO" -O second_video.mp4
  SECOND_VIDEO="second_video.mp4"
  echo "🟢 Adding second video: $SECOND_VIDEO"

  echo -e "file '$VIDEO'\nfile '$SECOND_VIDEO'" > concatlist.txt
  ffmpeg -hide_banner -y -f concat -safe 0 -i concatlist.txt -c copy temp_combined.mp4
  VIDEO="temp_combined.mp4"
  VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO")
  echo "🟢 New video duration: $VIDEO_DURATION sec"
fi

# 9️⃣ Drawtext logic
DRAW_TEXTS="drawtext=textfile='$INTRO':fontfile=$FONT:fontsize=64:fontcolor=$COLOR:box=1:boxcolor=$BOXCOLOR:boxborderw=12:x=(w-text_w)/2:y=(h-text_h)/3:enable='lt(t,$INTRO_DURATION)',"

for ((i=0; i<CHUNK_COUNT; i++)); do
  alpha_expr="if(lt(t,${STARTS[i]}+$FADEIN),(t-${STARTS[i]})/$FADEIN,if(lt(t,${STARTS[i]}+$FADEIN+$HOLD),1,if(lt(t,${STARTS[i]}+$FADEIN+$HOLD+$FADEOUT),1-(t-(${STARTS[i]}+$FADEIN+$HOLD))/$FADEOUT,0)))"
  DRAW_TEXTS+="drawtext=text='${CHUNKS[i]}':fontfile=$FONT:fontsize=48:fontcolor=$COLOR:x=(w-text_w)/2:y=(h-text_h)/2:alpha='$alpha_expr':box=1:boxcolor=$BOXCOLOR:boxborderw=10,"
done

DRAW_TEXTS+="drawtext=text='$OUTRO':fontfile=$FONT:fontsize=42:fontcolor=$COLOR:box=1:boxcolor=$BOXCOLOR:boxborderw=10:x=(w-text_w)/2:y=(h-text_h)/2:enable='between(t,${FINAL_DURATION}-3,${FINAL_DURATION})',"
DRAW_TEXTS+="drawtext=text='$WATERMARK':fontfile=$FONT:fontsize=24:fontcolor=white@0.7:x=w-tw-30:y=40:enable='between(t,0,$FINAL_DURATION)',"
DRAW_TEXTS+="drawtext=text='$CTA':fontfile=$FONT:fontsize=28:fontcolor=white@0.9:x=30:y=40:enable='between(t,$INTRO_DURATION,$FINAL_DURATION)'"

SCALE="scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920"
FILTER_COMPLEX="[0:v]$SCALE,$DRAW_TEXTS[v]"

# 🔟 Audio handling
HAS_AUDIO=$(ffprobe -loglevel error -select_streams a -show_entries stream=index -of csv=p=0 "$VIDEO" | wc -l)

if [ "$HAS_AUDIO" -eq 0 ]; then
  echo "🎧 Video has NO audio, using music only"
  ffmpeg -hide_banner -y \
    -i "$VIDEO" -i "$MUSIC" \
    -filter_complex "$FILTER_COMPLEX" \
    -map "[v]" -map 1:a \
    -t "$FINAL_DURATION" \
    -c:v libx264 -c:a aac \
    final.mp4
else
  echo "🎧 Mixing video audio with music"
  ffmpeg -hide_banner -y \
    -i "$VIDEO" -i "$MUSIC" \
    -filter_complex "$FILTER_COMPLEX;[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=2[a]" \
    -map "[v]" -map "[a]" \
    -t "$FINAL_DURATION" \
    -c:v libx264 -c:a aac \
    final.mp4
fi

echo "✅ Final wisdom video generated with consistent boxcolor for hook, content, outro — empire ready."
echo "▶️ Play with: ffplay final.mp4"
