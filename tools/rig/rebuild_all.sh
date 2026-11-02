#!/usr/bin/env bash
# Rebuild every game model from Logan's Meshy exports in assets/meshy/ (not in git).
# Characters are rigged, hats and guns are fitted; output goes to assets/rigged/.
#   bash tools/rig/rebuild_all.sh
set -e
cd "$(dirname "$0")/../.."
B="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
M=assets/meshy
R=assets/rigged
G=$R/guns
mkdir -p "$G"
rm -f $R/*.jpg $R/*.jpg.import $G/*.jpg $G/*.jpg.import $R/*.png $R/*.png.import $G/*.png $G/*.png.import

# "As sent": full detail and Meshy's own texture maps (Logan's call, 2026-11-02).
rig() { "$B" --background --factory-startup --python tools/rig/autorig.py -- "$1" "$2" --max-tris 300000 --keep-maps 2>&1 | grep -E "autorig\] (wrote|bones)|Error|Traceback" || true; }
hat() { "$B" --background --factory-startup --python tools/rig/prep_prop.py -- "$1" "$2" --size "$3" --max-tris 80000 2>&1 | grep -E "\[prop\] wrote|Error|Traceback" || true; }
gun() { "$B" --background --factory-startup --python tools/rig/prep_gun.py -- "$@" --max-tris 200000 --keep-maps 2>&1 | grep -E "\[gun\] wrote|Error|Traceback" || true; }

rig "$(ls $M/*Cowboy_Crash_Test_Dum*.glb)" $R/dummy_vest.glb
rig "$(ls $M/*Orange_Cowboy_Dummy*.glb)" $R/dummy_duster.glb
rig "$(ls $M/*Poncho_Cowboy_Dummy*.glb)" $R/dummy_poncho.glb
rig "$(ls $M/*Sheriff_Cowboy_Dummy*.glb)" $R/dummy_lawman.glb

hat "$(ls $M/*Cattleman_Cowboy_Hat*.glb)" $R/hat_cattleman.glb 0.5
hat "$(ls $M/*Ten_Gallon_Cowboy_Hat*.glb)" $R/hat_ten_gallon.glb 0.58
hat "$(ls $M/*Black_Gambler_Hat*.glb)" $R/hat_gambler.glb 0.46
hat "$(ls $M/*Bowler_Derby_Hat*.glb)" $R/hat_bowler.glb 0.34
hat "$(ls $M/*Straw_Sombrero_Hat*.glb)" $R/hat_sombrero.glb 0.86

gun "$(ls $M/*Colt_SAA_Revolver*.glb)" $G revolver --fit z --min -0.029,-0.117,-0.239 --max 0.029,0.072,0.115
gun "$(ls $M/*Winchester_1873_Rifle*.glb)" $G lever_rifle --fit z --min -0.022,-0.104,-0.655 --max 0.022,0.052,0.442 --shift 0,-0.037,0 \
	--part lever:-0.03,0.03,-0.115,-0.04,-0.02,0.085
gun "$(ls $M/*Coach_Shotgun*.glb)" $G coach_shotgun --fit z --min -0.035,-0.123,-0.525 --max 0.035,0.056,0.377 --shift 0,-0.033,0 \
	--part barrels:-0.06,0.06,-0.3,0.3,-0.6,-0.085
gun "$(ls $M/*Flintlock_Blunderbuss*.glb)" $G blunderbuss --fit z --min -0.045,-0.123,-0.445 --max 0.045,0.056,0.318 --shift 0,-0.028,0
# Crank on the left (turned by the left hand), stock cut off, centred on the barrels.
gun "$(ls $M/*Handheld_Crank_Gatlin*.glb)" $G crank_gatling --fit z --min -0.084,-0.10,-0.44 --max 0.12,0.114,0.12 --shift -0.028,-0.02,0 	--part stock:-0.2,0.2,-0.055,0.2,0.03,0.2 --part barrels:-0.06,0.06,-0.04,0.07,-0.45,-0.246 --part crank:-0.2,-0.058,-0.1,0.04,-0.25,-0.178
rm -f $G/crank_gatling_stock.glb
gun "$(ls $M/*Grappling_Hook_Pistol*.glb)" $G grapple --fit z --min -0.037,-0.129,-0.276 --max 0.061,0.017,-0.008
gun "$(ls $M/*Wooden_Water_Bucket*.glb)" $G bucket --fit y --min -0.09,-0.125,-0.104 --max 0.09,0.095,0.064
gun "$(ls $M/*Brass_Flip_Top_Lighte*.glb)" $G zippo --fit y --no-turn --min -0.018,0.0,-0.008 --max 0.018,0.0575,0.008 \
	--part lid:-0.05,0.05,0.0395,0.07,-0.05,0.05
echo "done"
