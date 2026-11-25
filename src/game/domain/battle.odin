package domain

import "core:math/rand"

// Fixed-size card pile: no allocation.
Pile :: struct {
	cards: [MAX_DECK]Card_Id,
	count: u8,
}

Battle_Phase :: enum u8 { Idle, Player_Turn, Won, Lost }

// Transient (not saved). The zero value is .Idle.
Battle :: struct {
	who:                Character_Id,
	phase:              Battle_Phase,
	turn:               u8,
	interest:           f32,
	energy:             u8,
	next_mult:          f32, // her Shy 0.5 / Warm 1.5 lands on your next card
	draw, hand, discard: Pile,
	next_move:          Ai_Move, // telegraphed to the player
	settled:            bool,    // finish_date already paid out
}

End_Turn_Result :: struct {
	applied:  Ai_Move, // the move she just made
	new_move: Ai_Move, // telegraphed for the next turn (valid if !ended)
	ended:    bool,
}

// ---------------------------------------------------------------- piles

pile_push :: proc(p: ^Pile, c: Card_Id) -> bool {
	if int(p.count) >= len(p.cards) { return false }
	p.cards[p.count] = c
	p.count += 1
	return true
}

pile_pop :: proc(p: ^Pile) -> (c: Card_Id, ok: bool) {
	if p.count == 0 { return .None, false }
	p.count -= 1
	return p.cards[p.count], true
}

// Removes slot i from `from` (keeping order) and pushes it onto `to`.
pile_move :: proc(from: ^Pile, i: u8, to: ^Pile) {
	c := from.cards[i]
	for j in int(i) ..< int(from.count) - 1 {
		from.cards[j] = from.cards[j + 1]
	}
	from.count -= 1
	from.cards[from.count] = .None
	pile_push(to, c)
}

pile_shuffle :: proc(p: ^Pile, gen: rand.Generator) {
	for i := int(p.count) - 1; i > 0; i -= 1 {
		j := rand.int_max(i + 1, gen)
		p.cards[i], p.cards[j] = p.cards[j], p.cards[i]
	}
}

// ---------------------------------------------------------------- decks / hints

deck_size :: proc(s: ^State, who: Character_Id) -> int {
	n := 0
	for c in Card_Id {
		if c != .None { n += int(s.decks[who][c]) }
	}
	return n
}

card_hint :: proc(s: ^State, who: Character_Id, c: Card_Def) -> Hint {
	if c.approach == .Generic { return .Always }
	if !s.known[who][c.approach] { return .Unknown }
	switch CHARACTERS[who].likes[c.approach] {
	case .Likes:    return .Works
	case .Neutral:  return .Flat
	case .Dislikes: return .Risky
	}
	return .Unknown
}

// ---------------------------------------------------------------- starting a date

date_start_blocker :: proc(s: ^State, b: ^Battle, who: Character_Id) -> Reject_Reason {
	if b.phase == .Player_Turn { return .Battle_In_Progress }
	return deck_blocker(s, who) // size + copy limits + ownership
}

// Expands decks[who] into a shuffled draw pile and deals the opening hand.
battle_start :: proc(s: ^State, b: ^Battle, who: Character_Id, gen: rand.Generator) -> Reject_Reason {
	if err := date_start_blocker(s, b, who); err != .None {
		return err
	}
	b^ = {}
	b.who       = who
	b.phase     = .Player_Turn
	b.turn      = 1
	b.energy    = ENERGY_PER_TURN
	b.next_mult = 1
	for c in Card_Id {
		if c == .None { continue }
		for _ in 0 ..< int(s.decks[who][c]) {
			pile_push(&b.draw, c)
		}
	}
	pile_shuffle(&b.draw, gen)
	draw_hand(b, HAND_DRAW, gen)
	b.next_move = ai_choose(b, CHARACTERS[who], gen)
	return .None
}

draw_hand :: proc(b: ^Battle, n: int, gen: rand.Generator) {
	for _ in 0 ..< n {
		if int(b.hand.count) >= MAX_HAND { return }
		if b.draw.count == 0 {
			// reshuffle discard into draw
			for b.discard.count > 0 {
				c, _ := pile_pop(&b.discard)
				pile_push(&b.draw, c)
			}
			pile_shuffle(&b.draw, gen)
		}
		c, ok := pile_pop(&b.draw)
		if !ok { return }
		pile_push(&b.hand, c)
	}
}

// ---------------------------------------------------------------- playing cards

play_blocker :: proc(s: ^State, b: ^Battle, slot: u8) -> Reject_Reason {
	if b.phase != .Player_Turn { return .Not_In_Battle }
	if slot >= b.hand.count    { return .Bad_Slot }
	if b.energy < CARDS[b.hand.cards[slot]].energy { return .No_Energy }
	return .None
}

resolve_card :: proc(c: Card_Def, who: Character_Def) -> (out: Outcome, delta: f32) {
	if c.approach == .Generic { return .Fine, c.power }
	r := who.likes[c.approach]
	delta = c.power * REACTION_MULT[r]
	switch r {
	case .Likes:    out = .Loved
	case .Neutral:  out = .Flat
	case .Dislikes: out = .Backfired
	}
	return
}

// Caller must have checked play_blocker.
play_card :: proc(s: ^State, b: ^Battle, slot: u8) -> Card_Played {
	id  := b.hand.cards[slot]
	def := CARDS[id]
	who := CHARACTERS[b.who]

	out, delta := resolve_card(def, who)
	delta *= b.next_mult
	b.next_mult = 1
	b.energy -= def.energy
	b.interest = clamp(b.interest + delta, 0, who.goal)
	pile_move(&b.hand, slot, &b.discard)

	learned := def.approach != .Generic && !s.known[b.who][def.approach]
	if learned { s.known[b.who][def.approach] = true }
	if b.interest >= who.goal { b.phase = .Won }
	return {card = id, outcome = out, delta = delta, learned = learned}
}

// ---------------------------------------------------------------- her turn

ai_choose :: proc(b: ^Battle, who: Character_Def, gen: rand.Generator) -> Ai_Move {
	w := who.ai
	if b.interest < who.goal * 0.4 { w[.Warm] = 0 } // she only warms up once it's going well
	total := 0
	for move in Ai_Move { total += int(w[move]) }
	if total <= 0 { return .Distracted }
	roll := rand.int_max(total, gen)
	for move in Ai_Move {
		if roll < int(w[move]) { return move }
		roll -= int(w[move])
	}
	return .Distracted
}

// Applies the telegraphed move, then starts the next turn (or ends the date).
end_turn :: proc(s: ^State, b: ^Battle, gen: rand.Generator) -> End_Turn_Result {
	who := CHARACTERS[b.who]
	res := End_Turn_Result{applied = b.next_move}

	switch b.next_move {
	case .Distracted: b.interest = max(0, b.interest - DISTRACTED_LOSS)
	case .Shy:        b.next_mult = 0.5
	case .Warm:       b.next_mult = 1.5
	}

	// discard the hand
	for b.hand.count > 0 {
		c, _ := pile_pop(&b.hand)
		pile_push(&b.discard, c)
	}

	b.turn += 1
	if b.turn > who.max_turns {
		b.phase = .Lost
		res.ended = true
		return res
	}

	draw_hand(b, HAND_DRAW, gen)
	b.energy = ENERGY_PER_TURN
	b.next_move = ai_choose(b, who, gen)
	res.new_move = b.next_move
	return res
}

battle_over :: proc(b: ^Battle) -> bool {
	return b.phase == .Won || b.phase == .Lost
}

// Pays out once when the date is over. Returns the affinity gained.
finish_date :: proc(s: ^State, b: ^Battle) -> (gained: Currency, ok: bool) {
	if !battle_over(b) || b.settled { return 0, false }
	b.settled = true
	if b.phase == .Won {
		s.affinity[b.who] += AFFINITY_PER_WIN
		s.insight[b.who]  += INSIGHT_PER_WIN
		return AFFINITY_PER_WIN, true
	}
	return 0, true // a failed date costs nothing beyond the missed reward
}
