package main

import "ecs"
import "domain"
import "vendor:raylib"

// ---------------------------------------------------------------- UI kit

WHITE :: raylib.Color{255, 255, 255, 255}

// Adds a node (Area + Layout + extras) to a scene and returns its Area so
// children can use it as their parent.
ui_node :: proc(sc: ^ecs.Scene, parent: ^Area, r: [4]f32, extra: ..any) -> ^Area {
	area_any, area := ecs.new_comp_ref(Area{})
	comps := make([dynamic]any, 0, 2 + len(extra), context.temp_allocator)
	append(&comps, area_any)
	append(&comps, ecs.new_comp(Layout{parent = parent, rect = r}))
	append(&comps, ..extra)
	ecs.scene_add(sc, comps[:]) // scene_add clones the slice
	return area
}

ui_panel :: proc(sc: ^ecs.Scene, parent: ^Area, r: [4]f32, color := raylib.Color{30, 34, 44, 255}) -> ^Area {
	return ui_node(sc, parent, r, ecs.new_comp(Panel{color = color}))
}

ui_label :: proc(sc: ^ecs.Scene, parent: ^Area, r: [4]f32, text := "", bind := Bind.None, arg := 0, size: i32 = 20) {
	ui_node(sc, parent, r, ecs.new_comp(Label{text = text, bind = bind, arg = arg, size = size, color = WHITE}))
}

ui_button :: proc(sc: ^ecs.Scene, parent: ^Area, r: [4]f32, text: string, on_click: domain.Event, selected := false) {
	ui_node(sc, parent, r,
		ecs.new_comp(Interactive{}),
		ecs.new_comp(Button{on_click = on_click, text = text, selected = selected}),
	)
}

ui_progress :: proc(sc: ^ecs.Scene, parent: ^Area, r: [4]f32, bind: Progress_Bind, color: raylib.Color) {
	ui_node(sc, parent, r, ecs.new_comp(Progress{bind = bind, color = color}))
}

// ---------------------------------------------------------------- HUD (persistent)

hud_build :: proc(w: ^World) -> ^ecs.Scene {
	sc := ecs.scene_init()
	bar := ui_panel(sc, &w.screen, {0, 0, 1, 0.08}, {18, 20, 28, 255})
	ui_label(sc, bar, {0.02, 0.15, 0.3, 0.7}, bind = .Coins)
	ui_label(sc, bar, {0.34, 0.15, 0.2, 0.7}, bind = .Income)
	ui_label(sc, bar, {0.58, 0.15, 0.4, 0.7}, bind = .Insight)
	return sc
}

// ---------------------------------------------------------------- Home

home_build :: proc(w: ^World) -> ^ecs.Scene {
	sc := ecs.scene_init()
	s := &w.screen
	focus := w.state.focus

	// focus tabs
	for who in domain.Character_Id {
		ui_button(sc, s, {0.02 + f32(int(who)) * 0.12, 0.10, 0.11, 0.06},
			domain.CHARACTERS[who].name, domain.Focus_Character_Requested{who}, selected = who == focus)
	}

	// notebook (rows are baked for the focused girl; Home rebuilds when focus changes)
	nb := ui_panel(sc, s, {0.02, 0.18, 0.28, 0.40})
	ui_label(sc, nb, {0.05, 0.03, 0.9, 0.12}, "Notebook", size = 18)
	row := 0
	for a in domain.Approach {
		if a == .Generic { continue }
		y := 0.20 + f32(row) * 0.26
		ui_label(sc, nb, {0.05, y, 0.55, 0.2}, bind = .Notebook_Row, arg = int(a), size = 16)
		ui_button(sc, nb, {0.62, y, 0.34, 0.2}, "Probe", domain.Probe_Requested{focus, a})
		row += 1
	}
	ui_label(sc, nb, {0.05, 0.92, 0.9, 0.07}, bind = .Probe_Cost, size = 12)

	// portrait + actions
	portrait := ui_panel(sc, s, {0.34, 0.18, 0.28, 0.40}, {70, 50, 90, 255})
	ui_label(sc, portrait, {0.05, 0.4, 0.9, 0.2}, bind = .Focus_Name, size = 28)
	ui_button(sc, s, {0.66, 0.20, 0.30, 0.12}, "Charm (+coins)", domain.Tapped{.Coins})
	ui_button(sc, s, {0.66, 0.36, 0.30, 0.12}, "Observe (+insight)", domain.Tapped{.Insight})

	// affinity
	ui_label(sc, s, {0.02, 0.61, 0.4, 0.05}, bind = .Affinity_Text, size = 18)
	ui_progress(sc, s, {0.02, 0.67, 0.6, 0.03}, .Affinity, {240, 120, 160, 255})

	// dialogue
	ui_panel(sc, s, {0.02, 0.73, 0.96, 0.07})
	ui_label(sc, s, {0.04, 0.74, 0.92, 0.05}, bind = .Dialogue, size = 18)

	// navigation
	ui_button(sc, s, {0.02, 0.84, 0.30, 0.11}, "Cards", domain.Scene_Change_Requested{.Shop})
	ui_button(sc, s, {0.35, 0.84, 0.30, 0.11}, "Date", domain.Date_Start_Requested{focus})
	ui_button(sc, s, {0.68, 0.84, 0.30, 0.11}, "Deck", domain.Scene_Change_Requested{.Deck})
	return sc
}

// ---------------------------------------------------------------- Shop

shop_build :: proc(w: ^World) -> ^ecs.Scene {
	sc := ecs.scene_init()
	s := &w.screen

	list := ui_panel(sc, s, {0.00, 0.10, 0.35, 0.80})
	for id in domain.Pack_Id {
		y := 0.05 + f32(int(id)) * 0.30
		ui_button(sc, list, {0.05, y, 0.90, 0.20}, domain.PACKS[id].name, domain.Buy_Pack_Requested{id})
		ui_label(sc, list, {0.08, y + 0.21, 0.84, 0.07}, bind = .Pack_Cost, arg = int(id), size = 16)
	}
	w.stage = ui_panel(sc, s, {0.37, 0.10, 0.61, 0.80}, {24, 40, 36, 255})
	ui_label(sc, s, {0.02, 0.92, 0.35, 0.05}, bind = .Collection_Progress, size = 18)
	ui_button(sc, s, {0.85, 0.92, 0.13, 0.06}, "Home", domain.Scene_Change_Requested{.Home})
	return sc
}

// ---------------------------------------------------------------- Date

date_build :: proc(w: ^World) -> ^ecs.Scene {
	sc := ecs.scene_init()
	s := &w.screen

	arena := ui_panel(sc, s, {0.02, 0.10, 0.96, 0.56})
	ui_label(sc, arena, {0.03, 0.04, 0.3, 0.1}, bind = .Turn_Text, size = 20)
	ui_label(sc, arena, {0.70, 0.04, 0.27, 0.1}, bind = .Energy_Text, size = 20)
	ui_label(sc, arena, {0.03, 0.40, 0.25, 0.1}, bind = .Draw_Count, size = 18)
	ui_label(sc, arena, {0.03, 0.52, 0.25, 0.1}, bind = .Discard_Count, size = 18)

	portrait := ui_panel(sc, arena, {0.36, 0.14, 0.28, 0.50}, {70, 50, 90, 255})
	ui_label(sc, portrait, {0.05, 0.4, 0.9, 0.2}, bind = .Focus_Name, size = 28)
	ui_label(sc, arena, {0.68, 0.30, 0.30, 0.1}, bind = .Next_Move_Text, size = 18)

	ui_label(sc, arena, {0.03, 0.74, 0.5, 0.08}, bind = .Interest_Text, size = 18)
	ui_progress(sc, arena, {0.03, 0.84, 0.60, 0.08}, .Interest, {240, 120, 160, 255})
	ui_button(sc, arena, {0.70, 0.76, 0.27, 0.18}, "End turn", domain.End_Turn_Requested{})

	// hand: a fixed set of slots, so nothing is spawned or despawned mid-battle
	for i in 0 ..< domain.MAX_HAND {
		x := 0.02 + f32(i) * 0.138
		ui_node(sc, s, {x, 0.70, 0.128, 0.26},
			ecs.new_comp(Hand_Slot{u8(i)}),
			ecs.new_comp(Card_View{}),
			ecs.new_comp(Interactive{}),
			ecs.new_comp(Button{on_click = domain.Play_Card_Requested{u8(i)}}),
		)
	}
	return sc
}

// ---------------------------------------------------------------- Deck

// Cards are listed by rarity (Common first), two columns, one row per card.
// Every row is baked for the focused character; the screen is rebuilt when
// the focus changes (see navigation_flow). Counts and button states are not
// baked: labels read the state each frame and `gate` greys the buttons.
deck_build :: proc(w: ^World) -> ^ecs.Scene {
	sc := ecs.scene_init()
	s := &w.screen
	focus := w.state.focus

	// character tabs + header
	for who in domain.Character_Id {
		ui_button(sc, s, {0.02 + f32(int(who)) * 0.12, 0.10, 0.11, 0.06},
			domain.CHARACTERS[who].name, domain.Focus_Character_Requested{who}, selected = who == focus)
	}
	ui_label(sc, s, {0.28, 0.10, 0.70, 0.04}, bind = .Deck_Title, size = 20)
	ui_label(sc, s, {0.28, 0.14, 0.70, 0.03}, bind = .Deck_Rules, size = 14)

	// card list
	list := ui_panel(sc, s, {0.02, 0.18, 0.96, 0.65})

	total := 0
	for c in domain.Card_Id {
		if c != .None { total += 1 }
	}
	rows_per_col := max((total + 1) / 2, 1)
	row_h := 0.97 / f32(rows_per_col)

	i := 0
	for rarity in domain.Rarity {
		for c in domain.Card_Id {
			if c == .None || domain.CARDS[c].rarity != rarity { continue }
			col, row := i / rows_per_col, i % rows_per_col
			i += 1

			r := ui_panel(sc, list, {0.01 + f32(col) * 0.50, 0.015 + f32(row) * row_h, 0.48, row_h - 0.008})
			ui_panel(sc, r, {0, 0, 0.012, 1}, rarity_color(rarity)) // rarity stripe
			ui_label(sc, r, {0.04, 0.06, 0.52, 0.45}, domain.CARDS[c].name, size = 15)
			ui_label(sc, r, {0.04, 0.52, 0.55, 0.40}, bind = .Deck_Card_Info, arg = int(c), size = 12)
			ui_label(sc, r, {0.58, 0.15, 0.20, 0.70}, bind = .Deck_Card_Count, arg = int(c), size = 14)
			ui_button(sc, r, {0.79, 0.15, 0.09, 0.70}, "-", domain.Deck_Remove_Requested{focus, c})
			ui_button(sc, r, {0.89, 0.15, 0.09, 0.70}, "+", domain.Deck_Add_Requested{focus, c})
		}
	}

	// footer
	ui_label(sc, s, {0.02, 0.85, 0.60, 0.05}, bind = .Deck_Status, size = 18)
	ui_button(sc, s, {0.66, 0.92, 0.17, 0.06}, "Auto-fill", domain.Deck_Auto_Fill_Requested{focus})
	ui_button(sc, s, {0.85, 0.92, 0.13, 0.06}, "Home", domain.Scene_Change_Requested{.Home})
	return sc
}
