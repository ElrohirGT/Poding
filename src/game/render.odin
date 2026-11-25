package main

import "core:fmt"
import "core:math"
import "core:strings"
import "ecs"
import "domain"
import "vendor:raylib"

// The only place that draws game UI. Read-only over World and the store.

COL_BG_BUTTON     :: raylib.Color{60, 70, 100, 255}
COL_BG_BUTTON_HOT :: raylib.Color{90, 105, 150, 255}
COL_BG_BUTTON_OFF :: raylib.Color{40, 42, 50, 255}
COL_BG_BUTTON_SEL :: raylib.Color{120, 80, 140, 255}
COL_TEXT_OFF      :: raylib.Color{120, 120, 130, 255}

fmt_num :: proc(v: f64) -> string {
	switch {
	case v >= 1e9: return fmt.tprintf("%.2fB", v / 1e9)
	case v >= 1e6: return fmt.tprintf("%.2fM", v / 1e6)
	case v >= 1e3: return fmt.tprintf("%.2fK", v / 1e3)
	}
	return fmt.tprintf("%.0f", v)
}

move_name :: proc(m: domain.Ai_Move) -> string {
	switch m {
	case .Distracted: return "Distracted"
	case .Shy:        return "Shy"
	case .Warm:       return "Warm"
	}
	return ""
}

label_text :: proc(w: ^World, l: ^Label) -> string {
	s := &w.state
	b := &w.battle
	switch l.bind {
	case .None:
		return l.text
	case .Coins:
		return fmt.tprintf("Coins %s", fmt_num(s.coins))
	case .Income:
		return fmt.tprintf("+%.1f/s", domain.coin_rate(s))
	case .Insight:
		return fmt.tprintf("Insight (%s) %s", domain.CHARACTERS[s.focus].name, fmt_num(s.insight[s.focus]))
	case .Collection_Progress:
		have, total := 0, 0
		for c in domain.Card_Id {
			if c == .None { continue }
			total += 1
			if s.collection[c] > 0 { have += 1 }
		}
		return fmt.tprintf("Collection %d/%d", have, total)
	case .Focus_Name:
		return domain.CHARACTERS[s.focus].name
	case .Affinity_Text:
		return fmt.tprintf("Affinity Lv %d (%.0f)", domain.affinity_level(s, s.focus), s.affinity[s.focus])
	case .Notebook_Row:
		a := domain.Approach(l.arg)
		if s.known[s.focus][a] {
			return fmt.tprintf("%s: %s", approach_name(a), reaction_name(domain.CHARACTERS[s.focus].likes[a]))
		}
		return fmt.tprintf("%s: ?", approach_name(a))
	case .Pack_Cost:
		id := domain.Pack_Id(l.arg)
		def := domain.PACKS[id]
		if !domain.requirement_met(s, def.requires) { return "Locked" }
		return fmt.tprintf("Cost %s", fmt_num(def.cost))
	case .Probe_Cost:
		return fmt.tprintf("Next probe: %s insight", fmt_num(domain.probe_cost(s, s.focus)))
	case .Turn_Text:
		return fmt.tprintf("Turn %d/%d", b.turn, domain.CHARACTERS[b.who].max_turns)
	case .Energy_Text:
		return fmt.tprintf("Energy %d/%d", b.energy, domain.ENERGY_PER_TURN)
	case .Next_Move_Text:
		if b.phase != .Player_Turn { return "" }
		return fmt.tprintf("She will: %s", move_name(b.next_move))
	case .Draw_Count:
		return fmt.tprintf("Draw %d", b.draw.count)
	case .Discard_Count:
		return fmt.tprintf("Discard %d", b.discard.count)
	case .Interest_Text:
		return fmt.tprintf("Interest %.0f/%.0f", b.interest, domain.CHARACTERS[b.who].goal)
	case .Dialogue:
		return fmt.tprintf("%s is waiting for you...", domain.CHARACTERS[s.focus].name)
	case .Deck_Title:
		return fmt.tprintf("%s's deck: %d/%d cards", domain.CHARACTERS[s.focus].name,
			domain.deck_size(s, s.focus), domain.MAX_DECK)
	case .Deck_Rules:
		return fmt.tprintf("Min %d cards. Max copies: Common %d, Rare %d, Epic %d, Legendary %d",
			domain.DECK_MIN,
			domain.COPY_LIMIT[.Common], domain.COPY_LIMIT[.Rare],
			domain.COPY_LIMIT[.Epic], domain.COPY_LIMIT[.Legendary])
	case .Deck_Status:
		n := domain.deck_size(s, s.focus)
		if n < domain.DECK_MIN {
			missing := domain.DECK_MIN - n
			return fmt.tprintf("Add %d more card%s to go on dates", missing, "" if missing == 1 else "s")
		}
		return "Deck ready"
	case .Deck_Card_Info:
		c := domain.Card_Id(l.arg)
		def := domain.CARDS[c]
		ht, _ := hint_text(domain.card_hint(s, s.focus, def))
		return fmt.tprintf("%s | %s | E%d P%.0f | %s",
			rarity_name(def.rarity), approach_name(def.approach), def.energy, def.power, ht)
	case .Deck_Card_Count:
		c := domain.Card_Id(l.arg)
		return fmt.tprintf("%d/%d (own %d)", s.decks[s.focus][c], domain.copy_limit(c), s.collection[c])
	}
	return ""
}

// ---------------------------------------------------------------- primitives

rl_rect :: proc(a: Area) -> raylib.Rectangle {
	return {a.x, a.y, a.z, a.w}
}

draw_text :: proc(text: string, x, y: f32, size: i32, color: raylib.Color) {
	c := strings.clone_to_cstring(text, context.temp_allocator)
	raylib.DrawText(c, i32(x), i32(y), size, color)
}

draw_text_centered :: proc(text: string, a: Area, size: i32, color: raylib.Color) {
	c := strings.clone_to_cstring(text, context.temp_allocator)
	tw := raylib.MeasureText(c, size)
	raylib.DrawText(c, i32(a.x + a.z / 2) - tw / 2, i32(a.y + a.w / 2) - size / 2, size, color)
}

// ---------------------------------------------------------------- passes

render_panels :: proc(w: ^World, z: u8) {
	for q in ecs.store_query2(w.store, ^Panel, ^Area) {
		if q.ct1.z != z { continue }
		raylib.DrawRectangleRec(rl_rect(q.ct2^), q.ct1.color)
		raylib.DrawRectangleLinesEx(rl_rect(q.ct2^), 1, {90, 94, 110, 255})
	}
}

render_buttons :: proc(w: ^World, z: u8) {
	for q in ecs.store_query3(w.store, ^Button, ^Interactive, ^Area) {
		btn, it, area := q.ct1, q.ct2, q.ct3
		if btn.z != z || btn.text == "" { continue } // text-less buttons are drawn by their entity (hand slots)
		bg := COL_BG_BUTTON
		switch {
		case !it.enabled:  bg = COL_BG_BUTTON_OFF
		case it.pressed:   bg = COL_BG_BUTTON_SEL
		case it.hovered:   bg = COL_BG_BUTTON_HOT
		case btn.selected: bg = COL_BG_BUTTON_SEL
		}
		raylib.DrawRectangleRec(rl_rect(area^), bg)
		raylib.DrawRectangleLinesEx(rl_rect(area^), 1, {150, 155, 180, 255})
		draw_text_centered(btn.text, area^, 18, WHITE if it.enabled else COL_TEXT_OFF)
	}
}

rarity_name :: proc(r: domain.Rarity) -> string {
	switch r {
	case .Common:    return "Common"
	case .Rare:      return "Rare"
	case .Epic:      return "Epic"
	case .Legendary: return "Legendary"
	}
	return ""
}

rarity_color :: proc(r: domain.Rarity) -> raylib.Color {
	switch r {
	case .Common: return {110, 120, 140, 255}
	case .Rare:   return {70, 130, 210, 255}
	case .Epic:   return {170, 90, 210, 255}
	case .Legendary: return {230, 170, 50, 255}
	}
	return {110, 120, 140, 255}
}

hint_text :: proc(h: domain.Hint) -> (string, raylib.Color) {
	switch h {
	case .Always:  return "ok", {170, 170, 170, 255}
	case .Unknown: return "?", {240, 220, 120, 255}
	case .Works:   return "works!", {120, 230, 140, 255}
	case .Flat:    return "flat", {160, 160, 160, 255}
	case .Risky:   return "risky", {240, 110, 110, 255}
	}
	return "", WHITE
}

render_cards :: proc(w: ^World) {
	for q in ecs.store_query2(w.store, ^Card_View, ^Area) {
		cv, area := q.ct1, q.ct2^
		if !cv.visible || cv.card == .None { continue }

		// flip: width collapses to 0 at flip = 0.5, then the face opens
		scale := abs(1 - 2 * cv.flip)
		showing_face := cv.face_up || cv.flip >= 0.5
		a := area
		a.z = area.z * max(scale, 0.02)
		a.x = area.x + (area.z - a.z) / 2
		if cv.hovered { a.y -= 8 }

		def := domain.CARDS[cv.card]
		if showing_face {
			raylib.DrawRectangleRec(rl_rect(a), {28, 30, 40, 255})
			raylib.DrawRectangleLinesEx(rl_rect(a), 3, rarity_color(def.rarity))
			if scale > 0.6 {
				draw_text(def.name, a.x + 6, a.y + 8, 12, WHITE)
				draw_text(fmt.tprintf("Energy %d", def.energy), a.x + 6, a.y + a.w - 38, 12, {200, 200, 120, 255})
				if cv.hint != .Always || cv.face_up {
					ht, hc := hint_text(cv.hint)
					draw_text(ht, a.x + 6, a.y + a.w - 20, 14, hc)
				}
				if cv.is_new { draw_text("NEW", a.x + a.z - 34, a.y + 8, 12, {255, 220, 80, 255}) }
			}
		} else {
			raylib.DrawRectangleRec(rl_rect(a), {50, 40, 80, 255})
			raylib.DrawRectangleLinesEx(rl_rect(a), 3, {120, 100, 170, 255})
		}
	}
}

render_labels :: proc(w: ^World, z: u8) {
	for q in ecs.store_query2(w.store, ^Label, ^Area) {
		l := q.ct1
		if l.z != z { continue }
		text := label_text(w, l)
		if text == "" { continue }
		size := l.size if l.size > 0 else 20
		a := q.ct2^
		// centred in its box vertically, left aligned
		draw_text(text, a.x, a.y + max(0, (a.w - f32(size)) / 2), size, l.color)
	}
}

render_progress :: proc(w: ^World, z: u8) {
	for q in ecs.store_query2(w.store, ^Progress, ^Area) {
		p, a := q.ct1, q.ct2^
		if p.z != z { continue }
		frac: f32
		switch p.bind {
		case .Affinity:
			frac = f32(math.mod(w.state.affinity[w.state.focus], domain.AFFINITY_PER_LEVEL)) / domain.AFFINITY_PER_LEVEL
		case .Interest:
			goal := domain.CHARACTERS[w.battle.who].goal
			frac = w.battle.interest / goal if goal > 0 else 0
		}
		frac = clamp(frac, 0, 1)
		raylib.DrawRectangleRec(rl_rect(a), {20, 20, 28, 255})
		raylib.DrawRectangleRec({a.x, a.y, a.z * frac, a.w}, p.color)
		raylib.DrawRectangleLinesEx(rl_rect(a), 1, {150, 155, 180, 255})
	}
}

render_toasts :: proc(w: ^World) {
	for q in ecs.store_query2(w.store, ^Toast, ^Area) {
		t, a := q.ct1, q.ct2^
		text := string(t.buf[:t.n])
		draw_text_centered(text, a, 18, {255, 240, 160, 255})
	}
}

render_all :: proc(w: ^World) {
	for z in u8(0) ..= 1 {
		render_panels(w, z)
		render_buttons(w, z)
		if z == 0 { render_cards(w) }
		render_progress(w, z)
		render_labels(w, z)
	}
	render_toasts(w)
}
