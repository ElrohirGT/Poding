package main

import "core:fmt"
import "ecs"
import "vendor:raylib"

setup_scenes :: proc(cfg: ^GameConfig) -> []^ecs.Scene {
	scenes := make([dynamic]^ecs.Scene)
	append(&scenes, windows_scene(cfg))
	fmt.printfln("SCENES:\n%#v", scenes)
	return scenes[:]
}

windows_scene :: proc(cfg: ^GameConfig) -> ^ecs.Scene {
	sc := ecs.scene_init()
	ecs.scene_add(sc, []any{
		ecs.new_comp(WindowArea{
			name = "Game",
			color = raylib.SKYBLUE,
			current_area = cfg.GameRectangle,
			ideal_area = cfg.GameRectangle
		})
	})
	game_area := sc.entities[0][0].(^WindowArea)

	ecs.scene_add(sc, []any {
		ecs.new_comp(WindowArea{
			name = "Debug",
			color = raylib.PINK,
			ideal_area = cfg.DebugRectangle,
			current_area = cfg.DebugRectangle
		})
	})

	ecs.scene_add(sc, []any {
		ecs.new_comp(WindowSubArea{
			name = "Battle Area",
			color = raylib.RED,
			parent = game_area,
			get_current = proc(p: Area) -> Area {
				return {10, 30, p.z - 20, p.w * 0.8 - 60}
			},
		})
	})

	ecs.scene_add(sc, []any{
		ecs.new_comp(Life{
			current = 5,
			sub_key = raylib.KeyboardKey.J,
			add_key = raylib.KeyboardKey.K,
			color = raylib.PINK,
			max = 5,
		}),
		ecs.new_comp(Area {100,100,0,0})
	})

	ecs.scene_add(sc, []any {
		ecs.new_comp(WindowSubArea{
			name = "Card Area",
			color = raylib.YELLOW,
			parent = game_area,
			get_current = proc(p: Area) -> Area {
				return {p.x+10, p.w * 0.8 - 15, p.z - 20, p.w *0.2}
				},
		})
	})

	ecs.scene_add(sc, []any {
		ecs.new_comp(WindowSubArea{
			name = "Player sprite",
			color = raylib.GREEN,
			parent = game_area,
			get_current = proc(p: Area) -> Area {
				return {p.x+20, p.w*0.55, 128, 128}
			}
		})
	})


	ecs.scene_add(sc, []any {
		ecs.new_comp(WindowSubArea{
			name = "Enemy sprite",
			color = raylib.ORANGE,
			parent = game_area,
			get_current = proc(p: Area) -> Area {
				return {p.z-128-20, p.y+50, 128, 128}
			}
		})
	})

	fmt.printfln("SCENE:\n%#v", sc)
	return sc
}
