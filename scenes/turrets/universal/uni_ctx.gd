class_name UniCtx
extends RefCounted
## What a universal turret's animation needs to know this frame (every peer).
## UniversalTurret fills it; gen/universal_*.gd animate() reads it.

## Loaded with a crop (fires this wave).
var loaded := false
var crop: StringName = &""
var color := CropEffects.EMPTY_COLOR
## Loading animation: 0 at the start of a load, 1 when done (and when not loading).
## Open lids / doors over the first ~0.3, pour in the middle, close by 1.
var load_k := 1.0
## Wave end: 0 as the crop starts draining away, 1 when empty and resting.
var drain_k := 1.0
## Shots fired (counts up on every peer) and seconds since the last one.
var shots := 0
var shot_age := 99.0
## Seconds of continuous fire (shots less than 0.8 s apart); 0 when idle.
var firing := 0.0
## 0 right after a shot, rising to 1 when the next is ready.
var charge := 1.0
## Hybrids: 0 quick mode, 1 heavy mode; mode_k eases between them (0..1).
var mode := 0
var mode_k := 0.0
## Seconds since the turret was set up (idle sways, spinning vanes).
var t := 0.0
## Upgrade tier 0-2.
var tier := 0
## A wave is on.
var in_wave := false
## Tracking a target right now.
var tracking := false
## Obstructions: placed this long ago; gone off (and how long ago).
var placed_age := 0.0
var triggered := false
var trigger_age := 99.0
## Health 0..1 (the palisade shows its wear).
var hp_frac := 1.0
## Crewed: someone is in the seat.
var crewed := false
## Crewed: barrel heat 0..1 and overheated (Iron Mule), barrel spin 0..1.
var heat := 0.0
var overheated := false
var spin := 0.0
## The gun's current pitch (radians, up positive) and the head's yaw.
var pitch := 0.0
var yaw := 0.0
