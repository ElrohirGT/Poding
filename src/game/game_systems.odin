package main

import "core:fmt"
import "ecs"
import "domain"

// Each system does one job. Rules systems are thin adapters: intent -> domain
// proc -> facts. Only they mutate w.state / w.battle.

// ---------------------------------------------------------------- layout / input

// Resolves Layout (fractions of the parent) into Area. Parents may be resolved
// after children when entities have been swapped around, so run a few passes.
layout :: proc(w: ^World) {
	for _ in 0 ..< 3 {
		for q in ecs.store_query2(w.store, ^Layout, ^Area) {
			l := q.ct1
			if l.parent == nil { continue }
			p := l.parent^
			q.ct2^ = Area{
				p.x + l.rect.x * p.z,
				p.y + l.rect.y * p.w,
				l.rect.z * p.z,
				l.rect.w * p.w,
			}
		}
	}
}

point_in :: proc(a: Area, p: [2]f32) -> bool {
	return p.x >= a.x && p.x <= a.x + a.z && p.y >= a.y && p.y <= a.y + a.w
}

hit_test :: proc(w: ^World) {
	for q in ecs.store_query2(w.store, ^Area, ^Interactive) {
		it := q.ct2
		it.clicked = false
		it.hovered = point_in(q.ct1^, w.input.mouse)
		if w.input.pressed && it.hovered { it.pressed = true }
		if w.input.released {
			it.clicked = it.pressed && it.hovered
			it.pressed = false
		}
	}
}

// Greys a button out exactly when the rules would reject its intent.
gate :: proc(w: ^World) {
	for q in ecs.store_query2(w.store, ^Button, ^Interactive) {
		q.ct2.enabled = domain.can_do(&w.state, &w.battle, q.ct1.on_click)
	}
}

// Clicked + enabled -> emit the button's event. Clicked + blocked -> say why.
button :: proc(w: ^World) {
	for q in ecs.store_query2(w.store, ^Button, ^Interactive) {
		if !q.ct2.clicked { continue }
		if q.ct2.enabled {
			domain.bus_emit(&w.bus, q.ct1.on_click)
		} else if q.ct1.on_click != nil {
			reason := domain.blocker_of(&w.state, &w.battle, q.ct1.on_click)
			if reason != .None {
				domain.bus_emit(&w.bus, domain.Action_Rejected{reason})
			}
		}
	}
}

// ---------------------------------------------------------------- rules

economy :: proc(w: ^World) {
	domain.economy_tick(&w.state, w.dt)
}

tap_rules :: proc(w: ^World) {
	for req in domain.bus_read(&w.bus, domain.Tapped) {
		amount := domain.tap(&w.state, req.what)
		domain.bus_emit(&w.bus, domain.Resource_Gained{req.what, amount})
	}
}

focus_rules :: proc(w: ^World) {
	for req in domain.bus_read(&w.bus, domain.Focus_Character_Requested) {
		if w.state.focus != req.who {
			w.state.focus = req.who
			domain.bus_emit(&w.bus, domain.Focus_Changed{req.who})
		}
	}
}

shop_rules :: proc(w: ^World) {
	for req in domain.bus_read(&w.bus, domain.Buy_Pack_Requested) {
		opened, err := domain.buy_pack(&w.state, req.pack, w.rng)
		if err != .None {
			domain.bus_emit(&w.bus, domain.Purchase_Rejected{req.pack, err})
		} else {
			domain.bus_emit(&w.bus, opened)
		}
	}
}

probe_rules :: proc(w: ^World) {
	for req in domain.bus_read(&w.bus, domain.Probe_Requested) {
		reaction, err := domain.probe(&w.state, req.who, req.approach)
		if err != .None {
			domain.bus_emit(&w.bus, domain.Action_Rejected{err})
		} else {
			domain.bus_emit(&w.bus, domain.Preference_Revealed{req.who, req.approach, reaction, .Probe})
		}
	}
}

date_start_rules :: proc(w: ^World) {
	for req in domain.bus_read(&w.bus, domain.Date_Start_Requested) {
		err := domain.battle_start(&w.state, &w.battle, req.who, w.rng)
		if err != .None {
			domain.bus_emit(&w.bus, domain.Action_Rejected{err})
		} else {
			domain.bus_emit(&w.bus, domain.Date_Started{req.who})
		}
	}
}

// Emits Date_Ended (once) if the battle just finished.
settle_if_over :: proc(w: ^World) {
	if gained, ok := domain.finish_date(&w.state, &w.battle); ok {
		domain.bus_emit(&w.bus, domain.Date_Ended{w.battle.who, w.battle.phase == .Won, gained})
	}
}

play_card_rules :: proc(w: ^World) {
	for req in domain.bus_read(&w.bus, domain.Play_Card_Requested) {
		if err := domain.play_blocker(&w.state, &w.battle, req.hand_index); err != .None {
			domain.bus_emit(&w.bus, domain.Action_Rejected{err})
			continue
		}
		who := w.battle.who
		res := domain.play_card(&w.state, &w.battle, req.hand_index)
		domain.bus_emit(&w.bus, domain.Card_Played{res.card, res.outcome, res.delta, res.learned})
		if res.learned {
			a := domain.CARDS[res.card].approach
			domain.bus_emit(&w.bus, domain.Preference_Revealed{who, a, domain.CHARACTERS[who].likes[a], .Date})
		}
		settle_if_over(w)
	}
}

end_turn_rules :: proc(w: ^World) {
	for _ in domain.bus_read(&w.bus, domain.End_Turn_Requested) {
		if w.battle.phase != .Player_Turn {
			domain.bus_emit(&w.bus, domain.Action_Rejected{.Not_In_Battle})
			continue
		}
		res := domain.end_turn(&w.state, &w.battle, w.rng)
		domain.bus_emit(&w.bus, domain.Ai_Acted{res.applied})
		if res.ended {
			settle_if_over(w)
		} else {
			domain.bus_emit(&w.bus, domain.Turn_Started{w.battle.turn})
		}
	}
}

deck_rules :: proc(w: ^World) {
	for req in domain.bus_read(&w.bus, domain.Deck_Add_Requested) {
		if err := domain.deck_add(&w.state, &w.battle, req.who, req.card); err != .None {
			domain.bus_emit(&w.bus, domain.Action_Rejected{err})
		} else {
			domain.bus_emit(&w.bus, domain.Deck_Changed{req.who})
		}
	}
	for req in domain.bus_read(&w.bus, domain.Deck_Remove_Requested) {
		if err := domain.deck_remove(&w.state, &w.battle, req.who, req.card); err != .None {
			domain.bus_emit(&w.bus, domain.Action_Rejected{err})
		} else {
			domain.bus_emit(&w.bus, domain.Deck_Changed{req.who})
		}
	}
	for req in domain.bus_read(&w.bus, domain.Deck_Auto_Fill_Requested) {
		if err := domain.deck_edit_blocker(&w.battle); err != .None {
			domain.bus_emit(&w.bus, domain.Action_Rejected{err})
		} else {
			domain.auto_deck(&w.state, req.who)
			domain.bus_emit(&w.bus, domain.Deck_Changed{req.who})
		}
	}
}

// The one non-UI emitter of intents: table of fact -> navigation.
navigation_flow :: proc(w: ^World) {
	date_starting := false
	for _ in domain.bus_read(&w.bus, domain.Date_Started) {
		date_starting = true
		domain.bus_emit(&w.bus, domain.Scene_Change_Requested{.Date})
	}
	// Home and Deck are built per focused girl (notebook rows / deck buttons),
	// so rebuild on a focus change.
	for _ in domain.bus_read(&w.bus, domain.Focus_Changed) {
		// (walking up to someone on the Home map changes focus and starts the date
		// in the same frame; the date wins, so Home is not rebuilt in that case)
		if w.active_id == .Deck || (w.active_id == .Home && !date_starting) {
			domain.bus_emit(&w.bus, domain.Scene_Change_Requested{w.active_id})
		}
	}
}

// ---------------------------------------------------------------- animation / lifetime

tween :: proc(w: ^World) {
	for t in ecs.store_query1(w.store, ^Tween) {
		if t.t < t.dur { t.t += w.dt }
		frac := clamp(t.t / t.dur, 0, 1)
		if t.target != nil {
			t.target^ = t.from + (t.to - t.from) * frac
		}
	}
}

lifetime :: proc(w: ^World) {
	for e in ecs.store_query1_ids(w.store, ^Lifetime) {
		e.c.remaining -= w.dt
		if e.c.remaining <= 0 {
			ecs.store_remove_entity(w.store, e.id)
		}
	}
}

// ---------------------------------------------------------------- feedback

reject_text :: proc(r: domain.Reject_Reason) -> string {
	switch r {
	case .None:               return ""
	case .Locked:             return "Locked"
	case .Cannot_Afford:      return "Not enough!"
	case .Bad_Target:         return "Can't do that"
	case .Already_Known:      return "Already known"
	case .Deck_Too_Small:     return "Deck too small"
	case .Battle_In_Progress: return "A date is in progress"
	case .Not_In_Battle:      return "Not on a date"
	case .Bad_Slot:           return "No card there"
	case .No_Energy:          return "Not enough energy"
	case .Not_Owned:          return "No more copies owned"
	case .Copy_Limit:         return "Copy limit reached"
	case .Deck_Full:          return "Deck is full"
	case .Not_In_Deck:        return "Not in the deck"
	}
	return ""
}

approach_name :: proc(a: domain.Approach) -> string {
	switch a {
	case .Generic:   return "Generic"
	case .Humor:     return "Humor"
	case .Knowledge: return "Knowledge"
	case .Boldness:  return "Boldness"
	}
	return ""
}

reaction_name :: proc(r: domain.Reaction) -> string {
	switch r {
	case .Neutral:  return "indifferent"
	case .Likes:    return "likes"
	case .Dislikes: return "dislikes"
	}
	return ""
}

// Pure table: event -> feedback text. New feedback is a new case.
fact_text :: proc(e: domain.Event) -> (text: string, ok: bool) {
	switch v in e {
	case domain.Action_Rejected:
		return reject_text(v.reason), v.reason != .None
	case domain.Purchase_Rejected:
		return reject_text(v.reason), v.reason != .None
	case domain.Resource_Gained:
		if v.what == .Coins { return fmt.tprintf("+%.0f coins", v.amount), true }
		return fmt.tprintf("+%.0f insight", v.amount), true
	case domain.Card_Played:
		switch v.outcome {
		case .Fine:      return fmt.tprintf("%+.0f", v.delta), true
		case .Loved:     return fmt.tprintf("She loved it! %+.0f", v.delta), true
		case .Flat:      return "It fell flat...", true
		case .Backfired: return fmt.tprintf("Backfired! %+.0f", v.delta), true
		}
	case domain.Preference_Revealed:
		return fmt.tprintf("%s %s %s", domain.CHARACTERS[v.who].name, reaction_name(v.reaction), approach_name(v.approach)), true
	case domain.Ai_Acted:
		switch v.move {
		case .Distracted: return "She got distracted (-interest)", true
		case .Shy:        return "She is shy: next card halved", true
		case .Warm:       return "She warms up: next card boosted", true
		}
	case domain.Pack_Opened, domain.Scene_Changed, domain.Reveal_Finished, domain.Focus_Changed,
	     domain.Date_Started, domain.Turn_Started, domain.Date_Ended,
	     domain.Scene_Change_Requested, domain.Tapped, domain.Buy_Pack_Requested,
	     domain.Focus_Character_Requested, domain.Date_Start_Requested, domain.Play_Card_Requested,
	     domain.End_Turn_Requested, domain.Probe_Requested, domain.Deck_Changed,
	     domain.Deck_Add_Requested, domain.Deck_Remove_Requested, domain.Deck_Auto_Fill_Requested:
		return "", false
	case nil:
		return "", false
	}
	return "", false
}

toast :: proc(w: ^World) {
	n := 0
	for e in w.bus.read {
		text, ok := fact_text(e)
		if !ok { continue }
		t: Toast
		count := min(len(text), len(t.buf))
		copy(t.buf[:count], text[:count])
		t.n = u8(count)
		// stack simultaneous toasts upward
		spawn_scoped(w,
			ecs.new_comp(Area{}),
			ecs.new_comp(Layout{parent = &w.screen, rect = {0.25, 0.90 - f32(n) * 0.045, 0.5, 0.04}}),
			ecs.new_comp(t),
			ecs.new_comp(Lifetime{remaining = 1.2, total = 1.2}),
		)
		n += 1
		if n >= 4 { break }
	}
}

// ---------------------------------------------------------------- shop: reveal

reveal_spawner :: proc(w: ^World) {
	for opened in domain.bus_read(&w.bus, domain.Pack_Opened) {
		if w.stage == nil { continue }
		// clear any previous reveal
		for e in ecs.store_query1_ids(w.store, ^Revealed) {
			ecs.store_remove_entity(w.store, e.id)
		}
		for i in 0 ..< int(opened.count) {
			cv_any, cv := ecs.new_comp_ref(Card_View{
				card = opened.cards[i], visible = true, is_new = opened.is_new[i],
			})
			spawn_scoped(w,
				ecs.new_comp(Area{}),
				ecs.new_comp(Layout{parent = w.stage, rect = {0.04 + f32(i) * 0.19, 0.2, 0.17, 0.6}}),
				cv_any,
				ecs.new_comp(Revealed{}),
				ecs.new_comp(Tween{target = &cv.flip, from = 0, to = 1, t = -0.5 * f32(i) - 0.2, dur = 0.5}),
			)
		}
		w.reveal_active = true
	}
}

reveal :: proc(w: ^World) {
	if !w.reveal_active { return }
	for t in ecs.store_query1(w.store, ^Tween) {
		if t.t < t.dur { return }
	}
	w.reveal_active = false
	domain.bus_emit(&w.bus, domain.Reveal_Finished{})
}

// ---------------------------------------------------------------- date

hand_view :: proc(w: ^World) {
	for q in ecs.store_query3(w.store, ^Hand_Slot, ^Card_View, ^Interactive) {
		cv := q.ct2
		idx := q.ct1.index
		if idx < w.battle.hand.count {
			id := w.battle.hand.cards[idx]
			cv.card    = id
			cv.visible = true
			cv.face_up = true
			cv.flip    = 1
			cv.hint    = domain.card_hint(&w.state, w.battle.who, domain.CARDS[id])
		} else {
			cv.visible = false
		}
		cv.hovered = q.ct3.hovered && q.ct3.enabled
	}
}

result_spawner :: proc(w: ^World) {
	for ended in domain.bus_read(&w.bus, domain.Date_Ended) {
		text := "She had a great time!" if ended.won else "She wasn't feeling it..."
		gained := fmt.tprintf("Affinity +%.0f", ended.affinity_gained)
		panel_any, panel := ecs.new_comp_ref(Area{})
		spawn_scoped(w,
			panel_any,
			ecs.new_comp(Layout{parent = &w.screen, rect = {0.2, 0.25, 0.6, 0.45}}),
			ecs.new_comp(Panel{color = {20, 20, 30, 245}, z = 1}),
		)
		spawn_scoped(w,
			ecs.new_comp(Area{}),
			ecs.new_comp(Layout{parent = panel, rect = {0.05, 0.12, 0.9, 0.15}}),
			ecs.new_comp(Label{text = text, size = 28, color = {255, 255, 255, 255}, z = 1}),
		)
		// `gained` lives in temp memory, so it is copied into a Toast-style buffer label.
		t: Toast
		count := min(len(gained), len(t.buf))
		copy(t.buf[:count], gained[:count])
		t.n = u8(count)
		spawn_scoped(w,
			ecs.new_comp(Area{}),
			ecs.new_comp(Layout{parent = panel, rect = {0.05, 0.35, 0.9, 0.12}}),
			ecs.new_comp(t),
		)
		spawn_scoped(w,
			ecs.new_comp(Area{}),
			ecs.new_comp(Layout{parent = panel, rect = {0.3, 0.65, 0.4, 0.2}}),
			ecs.new_comp(Interactive{}),
			ecs.new_comp(Button{on_click = domain.Scene_Change_Requested{.Home}, text = "Continue", z = 1}),
		)
	}
}

