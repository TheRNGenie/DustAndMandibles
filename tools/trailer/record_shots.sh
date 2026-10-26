#!/usr/bin/env bash
# Records every trailer shot with Godot's movie maker into trailer/raw/<shot>.avi
cd "$(dirname "$0")/../.."
SHOTS="${@:-opener crossfire faces boss storm snow dust bloodmoon homestead airship reload fall dummies endcard}"
for s in $SHOTS; do
  extra=""
  [ "$s" = "dummies" ] && extra="--thirdperson"
  echo "recording $s"
  timeout 900 ./Godot_v4.7.2-stable_win64_console.exe --path . --write-movie "trailer/raw/$s.avi" --fixed-fps 30 \
    res://scenes/world.tscn -- --trailer=$s $extra 2>&1 | grep -E "SCRIPT|at: res" | head -5
done
echo done
