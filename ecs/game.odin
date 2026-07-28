package main

import "ecs"
import "core:fmt"
import "core:time"
import "vendor:raylib"

main :: proc() {
	cfg := parse_file("cfg.toml")
	fmt.printfln("CFG: %#v", cfg)

	raylib.InitWindow(cfg.ScreenWidth, cfg.ScreenHeight, "Main Window")
	defer raylib.CloseWindow()

	store := ecs.init_store(5)
	defer ecs.deinit_store(store)

	ecs.register_component(store, Transform)
	ecs.register_component(store, RectangleRender)
	ecs.register_component(store, CircleRender)

	block_collision_scene(cfg, store)
	// state := block_collision_scene(cfg)
	// state := padel_collision_scene(cfg)
	// state := generate_default_scene(cfg)

	fmt.printfln("STORE:\n%#v", store)

	sec_in_ns: i64 = 1_000_000_000
	max_frame_duration := sec_in_ns / i64(cfg.FpsCap)
	lastFrameStart := time.now()._nsec - max_frame_duration
	for !raylib.WindowShouldClose() {
		{
			frame_start := time.now()._nsec
			raylib.BeginDrawing()
			defer raylib.EndDrawing()

			rects := ecs.query_1(store, RectangleRender)
			defer delete(rects)
			for &rect in rects {
				rectangle_renderer(&rect)
			}

			circs := ecs.query_1(store, CircleRender)
			defer delete(circs)
			for &circ in circs {
				circle_renderer(&circ)
			}

			// Gather input and update state
			// update(&state, f32(frame_start - lastFrameStart) / f32(sec_in_ns))

			// Render game
			// render(&state)

			lastFrameStart = time.now()._nsec
			time.sleep(cast(time.Duration)(max_frame_duration -(lastFrameStart - frame_start)))
		}
	}
}
