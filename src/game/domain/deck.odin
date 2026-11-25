package domain

// Deck building rules. Pure domain: every UI button and the rules system go
// through these procs, so "greyed out" and "rejected" always agree.
//
// A deck is valid when:
//   * it has DECK_MIN..MAX_DECK cards,
//   * no card appears more often than COPY_LIMIT[rarity]
//       (Common 5, Rare 3, Epic 1, Legendary 1),
//   * no card appears more often than the player owns it.

copy_limit :: proc(c: Card_Id) -> u8 {
	return COPY_LIMIT[CARDS[c].rarity]
}

deck_edit_blocker :: proc(b: ^Battle) -> Reject_Reason {
	if b.phase == .Player_Turn { return .Battle_In_Progress }
	return .None
}

deck_add_blocker :: proc(s: ^State, b: ^Battle, who: Character_Id, c: Card_Id) -> Reject_Reason {
	if c == .None { return .Bad_Target }
	if err := deck_edit_blocker(b); err != .None { return err }
	in_deck := s.decks[who][c]
	if u16(in_deck) >= s.collection[c]        { return .Not_Owned }
	if in_deck >= COPY_LIMIT[CARDS[c].rarity] { return .Copy_Limit }
	if deck_size(s, who) >= MAX_DECK          { return .Deck_Full }
	return .None
}

deck_remove_blocker :: proc(s: ^State, b: ^Battle, who: Character_Id, c: Card_Id) -> Reject_Reason {
	if c == .None { return .Bad_Target }
	if err := deck_edit_blocker(b); err != .None { return err }
	if s.decks[who][c] == 0 { return .Not_In_Deck }
	return .None
}

deck_add :: proc(s: ^State, b: ^Battle, who: Character_Id, c: Card_Id) -> Reject_Reason {
	if err := deck_add_blocker(s, b, who, c); err != .None { return err }
	s.decks[who][c] += 1
	return .None
}

deck_remove :: proc(s: ^State, b: ^Battle, who: Character_Id, c: Card_Id) -> Reject_Reason {
	if err := deck_remove_blocker(s, b, who, c); err != .None { return err }
	s.decks[who][c] -= 1
	return .None
}

// Whole-deck validation, used to gate starting a date.
deck_blocker :: proc(s: ^State, who: Character_Id) -> Reject_Reason {
	for c in Card_Id {
		if c == .None { continue }
		n := s.decks[who][c]
		if n == 0 { continue }
		if u16(n) > s.collection[c]        { return .Not_Owned }
		if n > COPY_LIMIT[CARDS[c].rarity] { return .Copy_Limit }
	}
	size := deck_size(s, who)
	if size > MAX_DECK { return .Deck_Full }
	if size < DECK_MIN { return .Deck_Too_Small }
	return .None
}

// Rebuilds decks[who] from the collection, obeying every deck rule.
// Preference: known-good cards, then generic, then unknown, then known
// Flat, then known Risky (the last two only if the deck would otherwise be
// short).
auto_deck :: proc(s: ^State, who: Character_Id, target := DECK_MIN) {
	s.decks[who] = {}
	picked := 0
	for tier in 0 ..< 5 {
		for c in Card_Id {
			if c == .None { continue }
			def := CARDS[c]
			want: int
			switch card_hint(s, who, def) {
			case .Works:   want = 0
			case .Always:  want = 1
			case .Unknown: want = 2
			case .Flat:    want = 3
			case .Risky:   want = 4
			}
			if want != tier { continue }
			limit := min(u16(COPY_LIMIT[def.rarity]), s.collection[c])
			for u16(s.decks[who][c]) < limit && picked < target {
				s.decks[who][c] += 1
				picked += 1
			}
		}
	}
}
