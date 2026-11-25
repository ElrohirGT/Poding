// Pure game domain: NO raylib, NO ecs imports.
package domain

import "core:math/rand"

// ---------------------------------------------------------------- ids / enums

Currency :: f64 // alias, so a Big type can replace it later

Scene_Id :: enum u8 { Home, Shop, Date }

Rarity :: enum u8 { Common, Rare, Epic }

Card_Id :: enum u8 { None, Compliment, Smile, Joke, Fun_Fact, Bold_Move }
Pack_Id :: enum u8 { Starter, Premium }
Character_Id :: enum u8 { Rin, Kai }

Resource :: enum u8 { Coins, Insight }

Approach :: enum u8 { Generic, Humor, Knowledge, Boldness }
Reaction :: enum u8 { Neutral, Likes, Dislikes } // Neutral = 0 so omitted entries are the safe default
Outcome  :: enum u8 { Fine, Loved, Flat, Backfired }
Ai_Move  :: enum u8 { Distracted, Shy, Warm }

Hint :: enum u8 { Always, Unknown, Works, Flat, Risky }

// Why an intent was refused. One enum for every rule so `can_do` and the rule
// procs share the exact same answer. `.None` means "allowed".
Reject_Reason :: enum u8 {
	None,
	Locked,
	Cannot_Afford,
	Bad_Target,
	Already_Known,
	Deck_Too_Small,
	Battle_In_Progress,
	Not_In_Battle,
	Bad_Slot,
	No_Energy,
}

// ---------------------------------------------------------------- tuning

MAX_PACK        :: 8
MAX_DECK        :: 40
MAX_HAND        :: 7
DECK_MIN        :: 10
HAND_DRAW       :: 5
ENERGY_PER_TURN :: 3

AFFINITY_PER_LEVEL :: 25.0
AFFINITY_PER_WIN   :: 20.0
INSIGHT_PER_WIN    :: 60.0
PITY_LIMIT         :: 5 // packs without a Rare+ before one is forced

BASE_COIN_RATE    :: 1.0
BASE_INSIGHT_RATE :: 0.5
TAP_COINS         :: 1.0
TAP_INSIGHT       :: 1.0
PROBE_BASE_COST   :: 50.0
DISTRACTED_LOSS   :: 8.0

REACTION_MULT := [Reaction]f32{.Neutral = 0, .Likes = 2, .Dislikes = -0.5}

// ---------------------------------------------------------------- requirements

Requirement  :: union { Min_Affinity, Owns_Cards } // nil = always available
Min_Affinity :: struct { who: Character_Id, level: u8 }
Owns_Cards   :: struct { count: u16 }              // total copies in collection

// ---------------------------------------------------------------- content tables

Pack_Def :: struct {
	name:     string,
	cost:     Currency,
	size:     u8,
	odds:     [Rarity]f32,
	requires: Requirement,
}

Card_Def :: struct {
	name:     string,
	approach: Approach,
	power:    f32,
	energy:   u8,
	rarity:   Rarity,
}

Character_Def :: struct {
	name:      string,
	likes:     [Approach]Reaction, // the hidden truth; Generic entry unused
	ai:        [Ai_Move]u8,        // move weights = personality
	goal:      f32,
	max_turns: u8,
}

PACKS := [Pack_Id]Pack_Def{
	.Starter = {name = "Starter Pack", cost = 50, size = 3,
	            odds = #partial [Rarity]f32{.Common = 0.9, .Rare = 0.1}},
	.Premium = {name = "Premium Pack", cost = 500, size = 5,
	            odds = [Rarity]f32{.Common = 0.6, .Rare = 0.3, .Epic = 0.1},
	            requires = Min_Affinity{.Rin, 2}},
}

// power = 12 x energy for specific cards; generic cards are 6 per energy.
// With evenly spread likes a blind specific card averages the same as generic.
CARDS := [Card_Id]Card_Def{
	.None       = {},
	.Compliment = {name = "Give a compliment",     approach = .Generic,   power = 6,  energy = 1, rarity = .Common},
	.Smile      = {name = "Smile at them",         approach = .Generic,   power = 3,  energy = 0, rarity = .Common},
	.Joke       = {name = "Say a joke",            approach = .Humor,     power = 12, energy = 1, rarity = .Rare},
	.Fun_Fact   = {name = "Explain a random fact", approach = .Knowledge, power = 12, energy = 1, rarity = .Rare},
	.Bold_Move  = {name = "Make a bold move",      approach = .Boldness,  power = 24, energy = 2, rarity = .Epic},
}

CHARACTERS := [Character_Id]Character_Def{
	.Rin = {name = "Rin", goal = 140, max_turns = 8,
	        likes = #partial [Approach]Reaction{.Humor = .Likes},
	        ai = {.Distracted = 3, .Shy = 2, .Warm = 1}},
	.Kai = {name = "Kai", goal = 140, max_turns = 8,
	        likes = #partial [Approach]Reaction{.Knowledge = .Likes, .Humor = .Dislikes},
	        ai = {.Distracted = 2, .Shy = 2, .Warm = 2}},
}

// ---------------------------------------------------------------- state

// Persistent game truth. Plain struct: serialisable, testable headless.
State :: struct {
	coins:      Currency,
	collection: [Card_Id]u16,                 // multiset as counts
	decks:      [Character_Id][Card_Id]u8,    // per-girl decks, as counts
	affinity:   [Character_Id]Currency,
	insight:    [Character_Id]Currency,
	known:      [Character_Id][Approach]bool, // reactions the player discovered
	focus:      Character_Id,
	pity:       [Pack_Id]u16,
}

// Helper so callers/tests can get a generator from a seed.
Seeded :: struct {
	state: rand.Default_Random_State,
}

seeded_init :: proc(s: ^Seeded, seed: u64) -> rand.Generator {
	s.state = rand.create(seed)
	return rand.default_random_generator(&s.state)
}
