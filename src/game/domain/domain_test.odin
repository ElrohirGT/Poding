package domain

import "core:testing"
import "core:math/rand"

new_gen :: proc(seeded: ^Seeded, seed: u64) -> rand.Generator {
	return seeded_init(seeded, seed)
}

@(test)
test_requirement_met :: proc(t: ^testing.T) {
	s: State
	testing.expect(t, requirement_met(&s, nil))
	testing.expect(t, !requirement_met(&s, Min_Affinity{.Rin, 2}))
	s.affinity[.Rin] = 2 * AFFINITY_PER_LEVEL
	testing.expect(t, requirement_met(&s, Min_Affinity{.Rin, 2}))
	testing.expect(t, !requirement_met(&s, Owns_Cards{3}))
	s.collection[.Joke] = 3
	testing.expect(t, requirement_met(&s, Owns_Cards{3}))
}

@(test)
test_economy_tick :: proc(t: ^testing.T) {
	s: State
	economy_tick(&s, 10)
	testing.expect_value(t, s.coins, BASE_COIN_RATE * 10)
	testing.expect_value(t, s.insight[.Rin], BASE_INSIGHT_RATE * 10)
	testing.expect_value(t, s.insight[.Kai], 0)
	s.focus = .Kai
	economy_tick(&s, 10)
	testing.expect_value(t, s.insight[.Kai], BASE_INSIGHT_RATE * 10)
}

@(test)
test_bus_double_buffer :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)
	b: Bus
	bus_init(&b)
	defer bus_deinit(&b)

	bus_emit(&b, Buy_Pack_Requested{.Starter})
	bus_emit(&b, Tapped{.Coins})
	testing.expect_value(t, len(bus_read(&b, Buy_Pack_Requested)), 0) // not readable in the same frame

	bus_swap(&b)
	reqs := bus_read(&b, Buy_Pack_Requested)
	testing.expect_value(t, len(reqs), 1)
	testing.expect_value(t, reqs[0].pack, Pack_Id.Starter)
	testing.expect_value(t, len(bus_read(&b, Tapped)), 1)

	bus_swap(&b) // nothing new was emitted
	testing.expect_value(t, len(bus_read(&b, Tapped)), 0)
}

@(test)
test_buy_pack :: proc(t: ^testing.T) {
	seeded: Seeded
	gen := new_gen(&seeded, 7)
	s: State
	s.coins = 50
	b: Battle

	testing.expect(t, can_do(&s, &b, Buy_Pack_Requested{.Starter}))
	opened, err := buy_pack(&s, .Starter, gen)
	testing.expect_value(t, err, Reject_Reason.None)
	testing.expect_value(t, opened.count, 3)
	testing.expect_value(t, s.coins, 0)
	testing.expect_value(t, owned_cards(&s), 3)
	for c in opened.cards[:opened.count] {
		testing.expect(t, c != .None)
	}

	// can_do and the rule agree
	testing.expect(t, !can_do(&s, &b, Buy_Pack_Requested{.Starter}))
	_, err = buy_pack(&s, .Starter, gen)
	testing.expect_value(t, err, Reject_Reason.Cannot_Afford)

	s.coins = 1000
	_, err = buy_pack(&s, .Premium, gen)
	testing.expect_value(t, err, Reject_Reason.Locked)
	testing.expect_value(t, s.coins, 1000) // rejected purchases cost nothing
}

@(test)
test_pity_forces_rare :: proc(t: ^testing.T) {
	seeded: Seeded
	gen := new_gen(&seeded, 11)
	s: State
	s.pity[.Starter] = PITY_LIMIT - 1
	for _ in 0 ..< 20 {
		s.pity[.Starter] = PITY_LIMIT - 1
		opened := roll_pack(&s, .Starter, gen)
		has_rare := false
		for c in opened.cards[:opened.count] {
			if CARDS[c].rarity != .Common { has_rare = true }
		}
		testing.expect(t, has_rare)
	}
}

@(test)
test_probe_cost_doubles :: proc(t: ^testing.T) {
	s: State
	b: Battle
	testing.expect_value(t, probe_cost(&s, .Rin), PROBE_BASE_COST)
	testing.expect(t, !can_do(&s, &b, Probe_Requested{.Rin, .Humor}))

	s.insight[.Rin] = 1000
	r, err := probe(&s, .Rin, .Humor)
	testing.expect_value(t, err, Reject_Reason.None)
	testing.expect_value(t, r, Reaction.Likes)
	testing.expect_value(t, s.insight[.Rin], 1000 - PROBE_BASE_COST)
	testing.expect_value(t, probe_cost(&s, .Rin), PROBE_BASE_COST * 2)

	_, err = probe(&s, .Rin, .Humor)
	testing.expect_value(t, err, Reject_Reason.Already_Known)
	_, err = probe(&s, .Rin, .Generic)
	testing.expect_value(t, err, Reject_Reason.Bad_Target)
}

@(test)
test_resolve_card :: proc(t: ^testing.T) {
	rin := CHARACTERS[.Rin]
	out, d := resolve_card(CARDS[.Compliment], rin)
	testing.expect_value(t, out, Outcome.Fine)
	testing.expect_value(t, d, 6)
	out, d = resolve_card(CARDS[.Joke], rin)
	testing.expect_value(t, out, Outcome.Loved)
	testing.expect_value(t, d, 24)
	out, d = resolve_card(CARDS[.Fun_Fact], rin)
	testing.expect_value(t, out, Outcome.Flat)
	testing.expect_value(t, d, 0)
	kai := CHARACTERS[.Kai]
	out, d = resolve_card(CARDS[.Joke], kai)
	testing.expect_value(t, out, Outcome.Backfired)
	testing.expect_value(t, d, -6)
}

@(test)
test_date_flow :: proc(t: ^testing.T) {
	seeded: Seeded
	gen := new_gen(&seeded, 3)
	s: State
	b: Battle

	testing.expect_value(t, date_start_blocker(&s, &b, .Rin), Reject_Reason.Deck_Too_Small)
	s.collection[.Joke] = 12
	s.decks[.Rin][.Joke] = 12
	testing.expect(t, can_do(&s, &b, Date_Start_Requested{.Rin}))
	testing.expect_value(t, battle_start(&s, &b, .Rin, gen), Reject_Reason.None)
	testing.expect_value(t, b.phase, Battle_Phase.Player_Turn)
	testing.expect_value(t, b.hand.count, HAND_DRAW)
	testing.expect_value(t, int(b.draw.count) + int(b.hand.count), 12)
	// double start is blocked while the date is in progress
	testing.expect(t, !can_do(&s, &b, Date_Start_Requested{.Rin}))

	// playing a specific card for the first time reveals the reaction
	testing.expect(t, !s.known[.Rin][.Humor])
	res := play_card(&s, &b, 0)
	testing.expect(t, res.learned)
	testing.expect_value(t, res.outcome, Outcome.Loved)
	testing.expect(t, s.known[.Rin][.Humor])
	testing.expect_value(t, b.energy, ENERGY_PER_TURN - 1)
	testing.expect_value(t, b.interest, 24)
	testing.expect_value(t, b.hand.count, HAND_DRAW - 1)

	// out of range slot / no energy
	testing.expect_value(t, play_blocker(&s, &b, 99), Reject_Reason.Bad_Slot)
	b.energy = 0
	testing.expect_value(t, play_blocker(&s, &b, 0), Reject_Reason.No_Energy)

	// a turn ends: hand redrawn, energy refilled, turn advances
	er := end_turn(&s, &b, gen)
	testing.expect(t, !er.ended)
	testing.expect_value(t, b.turn, 2)
	testing.expect_value(t, b.energy, ENERGY_PER_TURN)
	testing.expect_value(t, b.hand.count, HAND_DRAW)
}

@(test)
test_date_loses_after_max_turns_and_settles_once :: proc(t: ^testing.T) {
	seeded: Seeded
	gen := new_gen(&seeded, 5)
	s: State
	b: Battle
	s.decks[.Rin][.Smile] = 12
	battle_start(&s, &b, .Rin, gen)
	for b.phase == .Player_Turn {
		end_turn(&s, &b, gen)
	}
	testing.expect_value(t, b.phase, Battle_Phase.Lost)
	testing.expect_value(t, b.turn, CHARACTERS[.Rin].max_turns + 1)
	g, ok := finish_date(&s, &b)
	testing.expect(t, ok)
	testing.expect_value(t, g, 0)
	_, ok = finish_date(&s, &b)
	testing.expect(t, !ok) // idempotent
	testing.expect(t, !can_do(&s, &b, End_Turn_Requested{}))
}

@(test)
test_win_pays_out_once :: proc(t: ^testing.T) {
	seeded: Seeded
	gen := new_gen(&seeded, 9)
	s: State
	b: Battle
	s.decks[.Rin][.Joke] = 12
	battle_start(&s, &b, .Rin, gen)
	b.interest = CHARACTERS[.Rin].goal - 1
	play_card(&s, &b, 0)
	testing.expect_value(t, b.phase, Battle_Phase.Won)
	g, ok := finish_date(&s, &b)
	testing.expect(t, ok)
	testing.expect_value(t, g, AFFINITY_PER_WIN)
	testing.expect_value(t, s.affinity[.Rin], AFFINITY_PER_WIN)
	_, ok = finish_date(&s, &b)
	testing.expect(t, !ok)
	testing.expect_value(t, s.affinity[.Rin], AFFINITY_PER_WIN)
}

@(test)
test_card_hint :: proc(t: ^testing.T) {
	s: State
	testing.expect_value(t, card_hint(&s, .Kai, CARDS[.Compliment]), Hint.Always)
	testing.expect_value(t, card_hint(&s, .Kai, CARDS[.Joke]), Hint.Unknown)
	s.known[.Kai][.Humor] = true
	testing.expect_value(t, card_hint(&s, .Kai, CARDS[.Joke]), Hint.Risky)
	s.known[.Kai][.Knowledge] = true
	testing.expect_value(t, card_hint(&s, .Kai, CARDS[.Fun_Fact]), Hint.Works)
	s.known[.Rin][.Knowledge] = true
	testing.expect_value(t, card_hint(&s, .Rin, CARDS[.Fun_Fact]), Hint.Flat)
}

@(test)
test_auto_deck_prefers_known_good :: proc(t: ^testing.T) {
	s: State
	s.collection[.Compliment] = 10
	s.collection[.Joke] = 10
	s.collection[.Fun_Fact] = 10
	s.known[.Rin][.Humor] = true
	s.known[.Rin][.Knowledge] = true // Neutral for Rin => skipped
	auto_deck(&s, .Rin, 12)
	testing.expect_value(t, s.decks[.Rin][.Joke], 10)
	testing.expect_value(t, s.decks[.Rin][.Fun_Fact], 0)
	testing.expect_value(t, s.decks[.Rin][.Compliment], 2)
	testing.expect_value(t, deck_size(&s, .Rin), 12)
}

// ---------------------------------------------------------------- balance simulation

Bot_Mode :: enum { Blind, Informed }

// Greedy bot: best score per energy; free cards first. Blind bots treat
// unknown specific cards as worth the neutral average (power * 0.5).
bot_play_date :: proc(s: ^State, who: Character_Id, gen: rand.Generator) -> bool {
	b: Battle
	if battle_start(s, &b, who, gen) != .None { return false }
	// Snapshot: the bot decides only from what it knew when the date began,
	// even though play_card reveals reactions as the date goes on.
	known := s.known[who]
	for b.phase == .Player_Turn {
		best: int = -1
		best_score: f32 = 0
		for slot in 0 ..< int(b.hand.count) {
			if play_blocker(s, &b, u8(slot)) != .None { continue }
			def := CARDS[b.hand.cards[slot]]
			score: f32
			switch {
			case def.approach == .Generic:
				score = def.power
			case known[def.approach]:
				score = def.power * REACTION_MULT[CHARACTERS[who].likes[def.approach]]
			case:
				score = def.power * 0.5
			}
			if score <= 0 { continue }
			per := score / max(f32(def.energy), 0.5)
			if best == -1 || per > best_score {
				best = slot
				best_score = per
			}
		}
		if best == -1 {
			end_turn(s, &b, gen)
		} else {
			play_card(s, &b, u8(best))
		}
	}
	return b.phase == .Won
}

win_rate :: proc(who: Character_Id, deck: [Card_Id]u8, known_all: bool, dates: int, seed: u64) -> f64 {
	seeded: Seeded
	gen := new_gen(&seeded, seed)
	wins := 0
	for _ in 0 ..< dates {
		s: State
		s.decks[who] = deck
		if known_all {
			for a in Approach { s.known[who][a] = true }
		}
		if bot_play_date(&s, who, gen) { wins += 1 }
	}
	return f64(wins) / f64(dates)
}

@(test)
test_balance_targets :: proc(t: ^testing.T) {
	generic  := #partial [Card_Id]u8{.Compliment = 6, .Smile = 6}
	informed := #partial [Card_Id]u8{.Joke = 8, .Compliment = 2, .Smile = 2}
	blind    := #partial [Card_Id]u8{.Joke = 3, .Fun_Fact = 3, .Bold_Move = 3, .Compliment = 3}

	N :: 2000
	g := win_rate(.Rin, generic,  false, N, 1)
	i := win_rate(.Rin, informed, true,  N, 2)
	b := win_rate(.Rin, blind,    false, N, 3)

	testing.expectf(t, g > 0.30 && g < 0.58, "generic-only win rate %v not near 40%%", g)
	testing.expectf(t, i >= 0.85, "informed win rate %v below 85%%", i)
	testing.expectf(t, b < i - 0.30, "blind (%v) should be far below informed (%v)", b, i)
	testing.expectf(t, abs(b - g) < 0.15, "blind (%v) should be about as good as generic (%v)", b, g)
}
