package domain

// Intents ("I want X") are emitted by UI/timers and consumed by exactly one
// rules system. Facts ("X happened") are emitted only by rules systems and
// consumed by anyone. Events carry domain ids, never entity ids or pointers.

// ---- intents
Scene_Change_Requested    :: struct { to: Scene_Id }
Tapped                    :: struct { what: Resource }
Buy_Pack_Requested        :: struct { pack: Pack_Id }
Focus_Character_Requested :: struct { who: Character_Id }
Date_Start_Requested      :: struct { who: Character_Id }
Play_Card_Requested       :: struct { hand_index: u8 }
End_Turn_Requested        :: struct {}
Probe_Requested           :: struct { who: Character_Id, approach: Approach }
Deck_Add_Requested        :: struct { who: Character_Id, card: Card_Id }
Deck_Remove_Requested     :: struct { who: Character_Id, card: Card_Id }
Deck_Auto_Fill_Requested  :: struct { who: Character_Id }

// ---- facts
Scene_Changed       :: struct { to: Scene_Id }
Resource_Gained     :: struct { what: Resource, amount: Currency }
Pack_Opened         :: struct {
	pack:   Pack_Id,
	cards:  [MAX_PACK]Card_Id,
	count:  u8,
	is_new: [MAX_PACK]bool,
}
Purchase_Rejected   :: struct { pack: Pack_Id, reason: Reject_Reason }
Action_Rejected     :: struct { reason: Reject_Reason }
Reveal_Finished     :: struct {}
Focus_Changed       :: struct { who: Character_Id }
Date_Started        :: struct { who: Character_Id }
Card_Played         :: struct { card: Card_Id, outcome: Outcome, delta: f32, learned: bool }
Ai_Acted            :: struct { move: Ai_Move }
Turn_Started        :: struct { turn: u8 }
Reveal_Source       :: enum u8 { Probe, Date }
Preference_Revealed :: struct { who: Character_Id, approach: Approach, reaction: Reaction, source: Reveal_Source }
Date_Ended          :: struct { who: Character_Id, won: bool, affinity_gained: Currency }
Deck_Changed        :: struct { who: Character_Id }

Event :: union {
	// intents
	Scene_Change_Requested, Tapped, Buy_Pack_Requested, Focus_Character_Requested,
	Date_Start_Requested, Play_Card_Requested, End_Turn_Requested, Probe_Requested,
	Deck_Add_Requested, Deck_Remove_Requested, Deck_Auto_Fill_Requested,
	// facts
	Scene_Changed, Resource_Gained, Pack_Opened, Purchase_Rejected, Action_Rejected,
	Reveal_Finished, Focus_Changed, Date_Started, Card_Played, Ai_Acted, Turn_Started,
	Preference_Revealed, Date_Ended, Deck_Changed,
}

// Double-buffered: events emitted in frame N are readable in frame N+1.
// Uses the default allocator (not temp) so capacity is reused across frames.
Bus :: struct {
	read, write: [dynamic]Event,
}

bus_init :: proc(b: ^Bus) {
	b.read  = make([dynamic]Event)
	b.write = make([dynamic]Event)
}

bus_deinit :: proc(b: ^Bus) {
	delete(b.read)
	delete(b.write)
}

bus_emit :: proc(b: ^Bus, e: Event) {
	append(&b.write, e)
}

// Call once per frame.
bus_swap :: proc(b: ^Bus) {
	clear(&b.read)
	b.read, b.write = b.write, b.read
}

// Events of one variant readable this frame. Slice lives in temp_allocator.
bus_read :: proc(b: ^Bus, $T: typeid) -> []T {
	out := make([dynamic]T, 0, 4, context.temp_allocator)
	for e in b.read {
		if v, ok := e.(T); ok {
			append(&out, v)
		}
	}
	return out[:]
}
