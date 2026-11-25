package domain

import "core:math/rand"

// ---------------------------------------------------------------- affinity / income

affinity_level :: proc(s: ^State, who: Character_Id) -> u8 {
	return u8(min(s.affinity[who] / AFFINITY_PER_LEVEL, 255))
}

total_affinity_levels :: proc(s: ^State) -> int {
	n := 0
	for who in Character_Id {
		n += int(affinity_level(s, who))
	}
	return n
}

coin_rate :: proc(s: ^State) -> Currency {
	return BASE_COIN_RATE * (1 + 0.1 * Currency(total_affinity_levels(s)))
}

insight_rate :: proc(s: ^State) -> Currency {
	return BASE_INSIGHT_RATE * (1 + 0.25 * Currency(affinity_level(s, s.focus)))
}

// Also serves offline catch-up: economy_tick(&s, away_seconds).
economy_tick :: proc(s: ^State, dt: f32) {
	s.coins            += coin_rate(s) * Currency(dt)
	s.insight[s.focus] += insight_rate(s) * Currency(dt)
}

owned_cards :: proc(s: ^State) -> int {
	n := 0
	for c in Card_Id {
		if c != .None { n += int(s.collection[c]) }
	}
	return n
}

// The one gating predicate (packs, nav unlocks, card pools).
requirement_met :: proc(s: ^State, r: Requirement) -> bool {
	switch v in r {
	case nil:          return true
	case Min_Affinity: return affinity_level(s, v.who) >= v.level
	case Owns_Cards:   return owned_cards(s) >= int(v.count)
	}
	return true
}

// ---------------------------------------------------------------- tapping / focus

tap :: proc(s: ^State, what: Resource) -> Currency {
	switch what {
	case .Coins:
		s.coins += TAP_COINS
		return TAP_COINS
	case .Insight:
		s.insight[s.focus] += TAP_INSIGHT
		return TAP_INSIGHT
	}
	return 0
}

// ---------------------------------------------------------------- probing

known_count :: proc(s: ^State, who: Character_Id) -> int {
	n := 0
	for a in Approach {
		if a != .Generic && s.known[who][a] { n += 1 }
	}
	return n
}

probe_cost :: proc(s: ^State, who: Character_Id) -> Currency {
	return PROBE_BASE_COST * Currency(int(1) << uint(known_count(s, who)))
}

probe_blocker :: proc(s: ^State, who: Character_Id, a: Approach) -> Reject_Reason {
	if a == .Generic                    { return .Bad_Target }
	if s.known[who][a]                  { return .Already_Known }
	if s.insight[who] < probe_cost(s, who) { return .Cannot_Afford }
	return .None
}

probe :: proc(s: ^State, who: Character_Id, a: Approach) -> (Reaction, Reject_Reason) {
	if err := probe_blocker(s, who, a); err != .None {
		return .Neutral, err
	}
	s.insight[who] -= probe_cost(s, who) // cost uses the count BEFORE this reveal
	s.known[who][a] = true
	return CHARACTERS[who].likes[a], .None
}

// ---------------------------------------------------------------- packs

pack_blocker :: proc(s: ^State, id: Pack_Id) -> Reject_Reason {
	def := PACKS[id]
	if !requirement_met(s, def.requires) { return .Locked }
	if s.coins < def.cost                { return .Cannot_Afford }
	return .None
}

roll_rarity :: proc(odds: [Rarity]f32, gen: rand.Generator) -> Rarity {
	total: f32 = 0
	for r in Rarity { total += odds[r] }
	if total <= 0 { return .Common }
	roll := rand.float32(gen) * total
	for r in Rarity {
		if roll < odds[r] { return r }
		roll -= odds[r]
	}
	return .Common
}

pick_card :: proc(r: Rarity, gen: rand.Generator) -> Card_Id {
	pool: [len(Card_Id)]Card_Id
	n := 0
	for c in Card_Id {
		if c != .None && CARDS[c].rarity == r {
			pool[n] = c
			n += 1
		}
	}
	if n == 0 && r != .Common { return pick_card(.Common, gen) }
	if n == 0 { return .None }
	return pool[rand.int_max(n, gen)]
}

roll_pack :: proc(s: ^State, id: Pack_Id, gen: rand.Generator) -> Pack_Opened {
	def := PACKS[id]
	opened := Pack_Opened{pack = id, count = min(def.size, MAX_PACK)}
	got_rare := false
	for i in 0 ..< int(opened.count) {
		r := roll_rarity(def.odds, gen)
		// Pity: force a Rare on the last slot if the streak limit was reached.
		if i == int(opened.count) - 1 && !got_rare && s.pity[id] >= PITY_LIMIT - 1 {
			r = .Rare
		}
		if r != .Common { got_rare = true }
		opened.cards[i] = pick_card(r, gen)
	}
	s.pity[id] = 0 if got_rare else s.pity[id] + 1
	return opened
}

buy_pack :: proc(s: ^State, id: Pack_Id, gen: rand.Generator) -> (opened: Pack_Opened, err: Reject_Reason) {
	if err = pack_blocker(s, id); err != .None {
		return {}, err
	}
	s.coins -= PACKS[id].cost
	opened = roll_pack(s, id, gen)
	for c, i in opened.cards[:opened.count] {
		opened.is_new[i] = s.collection[c] == 0
		s.collection[c] += 1 // duplicates just add copies
	}
	return opened, .None
}

// ---------------------------------------------------------------- single answer for the UI

// A button greys out exactly when the rule proc would reject the intent.
can_do :: proc(s: ^State, b: ^Battle, intent: Event) -> bool {
	switch v in intent {
	case Buy_Pack_Requested:   return pack_blocker(s, v.pack) == .None
	case Probe_Requested:      return probe_blocker(s, v.who, v.approach) == .None
	case Date_Start_Requested: return date_start_blocker(s, b, v.who) == .None
	case Play_Card_Requested:  return play_blocker(s, b, v.hand_index) == .None
	case End_Turn_Requested:   return b.phase == .Player_Turn
	case Scene_Change_Requested, Tapped, Focus_Character_Requested,
	     Scene_Changed, Resource_Gained, Pack_Opened, Purchase_Rejected, Action_Rejected,
	     Reveal_Finished, Focus_Changed, Date_Started, Card_Played, Ai_Acted, Turn_Started,
	     Preference_Revealed, Date_Ended:
		return true
	case nil:
		return false
	}
	return true
}

// Reason for the intent being blocked (.None if allowed); used for toasts.
blocker_of :: proc(s: ^State, b: ^Battle, intent: Event) -> Reject_Reason {
	switch v in intent {
	case Buy_Pack_Requested:   return pack_blocker(s, v.pack)
	case Probe_Requested:      return probe_blocker(s, v.who, v.approach)
	case Date_Start_Requested: return date_start_blocker(s, b, v.who)
	case Play_Card_Requested:  return play_blocker(s, b, v.hand_index)
	case End_Turn_Requested:   return .None if b.phase == .Player_Turn else .Not_In_Battle
	case Scene_Change_Requested, Tapped, Focus_Character_Requested,
	     Scene_Changed, Resource_Gained, Pack_Opened, Purchase_Rejected, Action_Rejected,
	     Reveal_Finished, Focus_Changed, Date_Started, Card_Played, Ai_Acted, Turn_Started,
	     Preference_Revealed, Date_Ended:
		return .None
	case nil:
		return .None
	}
	return .None
}
