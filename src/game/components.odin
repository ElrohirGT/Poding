package main

import "ecs"
import "domain"
import "vendor:raylib"

// `Area` ([4]f32: x, y, width(.z), height(.w)) doubles as the resolved screen
// rectangle of any UI entity. It is declared in systems.odin.

// Resolves to an Area as fractions of `parent`.
Layout :: struct {
	parent: ^Area,
	rect:   [4]f32, // x, y, w, h as fractions of the parent
}

Interactive :: struct {
	enabled, hovered, pressed, clicked: bool,
}

// Data: what to emit on click, not what it does. A nil event is a disabled
// placeholder button.
Button :: struct {
	on_click: domain.Event,
	text:     string,
	selected: bool,
	z:        u8,
}

Panel :: struct {
	color: raylib.Color,
	z:     u8,
}

Bind :: enum u8 {
	None,
	Coins,
	Income,
	Insight,
	Collection_Progress,
	Focus_Name,
	Affinity_Text,
	Notebook_Row, // arg = Approach
	Pack_Cost,    // arg = Pack_Id
	Probe_Cost,
	Turn_Text,
	Energy_Text,
	Next_Move_Text,
	Draw_Count,
	Discard_Count,
	Interest_Text,
	Dialogue,
	Deck_Title,
	Deck_Rules,
	Deck_Status,
	Deck_Card_Info,  // arg = Card_Id
	Deck_Card_Count, // arg = Card_Id
}

Label :: struct {
	text:  string, // used when bind == .None
	bind:  Bind,
	arg:   int,
	size:  i32,
	color: raylib.Color,
	z:     u8,
}

Progress_Bind :: enum u8 { Affinity, Interest }

Progress :: struct {
	bind:  Progress_Bind,
	color: raylib.Color,
	z:     u8,
}

Hand_Slot :: struct { index: u8 }

Card_View :: struct {
	card:    domain.Card_Id,
	hint:    domain.Hint,
	visible: bool,
	face_up: bool,  // reveal cards: face-up once flip >= 0.5
	flip:    f32,   // 0..1
	hovered: bool,
	is_new:  bool,
}

// Marks cards spawned by the pack reveal so a new pack can clear the old ones.
Revealed :: struct {}

// Keep on the SAME entity as its target.
Tween :: struct {
	target:        ^f32,
	from, to:      f32,
	t, dur:        f32, // t < 0 is a start delay
}

Lifetime :: struct { remaining, total: f32 }

Toast :: struct {
	buf: [64]u8,
	n:   u8,
}

// Entities spawned by systems (not by the scene builder) are tagged so the
// scene manager can remove them when the screen changes.
Scoped :: struct { scene: domain.Scene_Id }

register_components :: proc(st: ^ecs.Store) {
	ecs.store_register_component(st, ^Area)
	ecs.store_register_component(st, ^Layout)
	ecs.store_register_component(st, ^Interactive)
	ecs.store_register_component(st, ^Button)
	ecs.store_register_component(st, ^Panel)
	ecs.store_register_component(st, ^Label)
	ecs.store_register_component(st, ^Progress)
	ecs.store_register_component(st, ^Hand_Slot)
	ecs.store_register_component(st, ^Card_View)
	ecs.store_register_component(st, ^Revealed)
	ecs.store_register_component(st, ^Tween)
	ecs.store_register_component(st, ^Lifetime)
	ecs.store_register_component(st, ^Toast)
	ecs.store_register_component(st, ^Scoped)
}
