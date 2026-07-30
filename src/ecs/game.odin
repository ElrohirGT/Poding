package main

import "ecs"
import "core:fmt"
import "core:time"
import "core:c"
import "core:strings"
import "vendor:raylib"
import "vendor:microui"

FontSize :: 14

enable_debug := false
frame := true

text_width :: proc(font: microui.Font, str: string) -> i32 {
	cstr, err := strings.clone_to_cstring(str)
	if err != nil {
		panic("Failed to convert to cstring")
	}
	return raylib.MeasureText(cstr, FontSize)
}

text_height :: proc(font: microui.Font) -> i32 {
	return FontSize
}

main :: proc() {
	cfg := parse_file("cfg.toml")
	fmt.printfln("CFG: %#v", cfg)

	ctx := &microui.Context{}
	microui.init(ctx)
	ctx.text_width = text_width
	ctx.text_height = text_height

	raylib.InitWindow(cfg.ScreenWidth, cfg.ScreenHeight, "Main Window")
	defer raylib.CloseWindow()

	store := ecs.init_store(5)
	defer ecs.deinit_store(store)

	ecs.register_component(store, ^Transform)
	ecs.register_component(store, ^RectangleRender)
	ecs.register_component(store, ^CircleRender)
	ecs.register_component(store, ^SquareCollider)
	ecs.register_component(store, ^PadelMovement)

	// block_collision_scene(cfg, store)
	// padel_collision_scene(cfg, store)
	generate_default_scene(cfg, store)

	fmt.printfln("STORE:\n%#v", store)

	sec_in_ns: i64 = 1_000_000_000
	max_frame_duration := sec_in_ns / i64(cfg.FpsCap)
	lastFrameStart := time.now()._nsec - max_frame_duration
	for !raylib.WindowShouldClose() {
		{
			frame_start := time.now()._nsec
			raylib.BeginDrawing()
			defer raylib.EndDrawing()
			defer free_all(context.temp_allocator)
			defer { frame = !enable_debug || false }

			// Get user input
			get_input(ctx)

			{
				microui.begin(ctx)
				defer microui.end(ctx)

				// Render game state
				render(store, cfg)

				// Update game state
				systems(ctx, store, f32(frame_start - lastFrameStart) / f32(sec_in_ns))

				// Debug windows
				if enable_debug {
					debug_ui(ctx, store)
				}
			}

			render_ui(ctx)

			lastFrameStart = time.now()._nsec
			time.sleep(cast(time.Duration)(max_frame_duration -(lastFrameStart - frame_start)))
		}
	}
}

get_input :: proc(ctx: ^microui.Context) {
	mouseX := raylib.GetMouseX()
	mouseY := raylib.GetMouseY()
	microui.input_mouse_move(ctx, mouseX, mouseY)

	mouseScroll := raylib.GetMouseWheelMoveV()
	microui.input_scroll(ctx, cast(i32)mouseScroll.x, cast(i32)mouseScroll.y)

	switch {
	case raylib.IsMouseButtonPressed(raylib.MouseButton.LEFT):
		microui.input_mouse_down(ctx, mouseX, mouseY, microui.Mouse.LEFT)
	case raylib.IsMouseButtonPressed(raylib.MouseButton.RIGHT):
		microui.input_mouse_down(ctx, mouseX, mouseY, microui.Mouse.RIGHT)
	case raylib.IsMouseButtonPressed(raylib.MouseButton.MIDDLE):
		microui.input_mouse_down(ctx, mouseX, mouseY, microui.Mouse.MIDDLE)
	}

	switch {
	case raylib.IsMouseButtonReleased(raylib.MouseButton.LEFT):
		microui.input_mouse_up(ctx, mouseX, mouseY, microui.Mouse.LEFT)
	case raylib.IsMouseButtonReleased(raylib.MouseButton.RIGHT):
		microui.input_mouse_up(ctx, mouseX, mouseY, microui.Mouse.RIGHT)
	case raylib.IsMouseButtonReleased(raylib.MouseButton.MIDDLE):
		microui.input_mouse_up(ctx, mouseX, mouseY, microui.Mouse.MIDDLE)
	}

	for k := raylib.GetKeyPressed(); k != raylib.KeyboardKey.KEY_NULL; k = raylib.GetKeyPressed() {
		microui.input_key_down(ctx, cast(microui.Key)k)

		size: c.int
		c_text := raylib.CodepointToUTF8(raylib.GetCharPressed(), &size)
		text, err := strings.clone_from_cstring_bounded(c_text, int(size))
		if err != nil {
			panic("Failed to clone to odin string")
		}
		if len(text) > 0 {
			microui.input_text(ctx, text)
			fmt.printfln("Got text: %s - %s | %d", text, ctx.text_input.buf[:], strings.builder_len(ctx.text_input))
		}
	}

	if raylib.IsKeyPressed(.ENTER) {
		enable_debug = !enable_debug
	}

	if raylib.IsKeyPressed(.SPACE) {
		frame = true
	}
}

render :: proc(store: ^ecs.Store, cfg: ^GameConfig) {
	raylib.ClearBackground(cfg.BackgroundColor)
	rects := ecs.query_2(store, ^RectangleRender, ^Transform)
	rectangle_renderer(rects)

	circs := ecs.query_2(store, ^CircleRender, ^Transform)
	circle_renderer(circs)
}

systems :: proc(ctx: ^microui.Context, store: ^ecs.Store, dt: f32) {
	reset_collisions(ecs.query_1(store, ^SquareCollider))
	apply_padel_movement(ecs.query_2(store, ^PadelMovement, ^Transform))

	colls := ecs.query_2(store, ^SquareCollider, ^Transform)
	check_collisions(colls)
	bounce_ball(colls)
	drop_block(colls, store)

	trans := ecs.query_1(store, ^Transform)
	movement(trans, dt)
}

debug_ui :: proc(ctx: ^microui.Context, store: ^ecs.Store) {
	dbg_entities(ctx, store)
	dbg_collisions(ctx, ecs.query_2(store, ^SquareCollider, ^Transform))
}

render_ui :: proc(ctx: ^microui.Context) {
	pcm: ^microui.Command = nil
	for microui.next_command(ctx, &pcm) {
		switch v in pcm.variant{
		case ^microui.Command_Jump: // Not implemented even on the demo xD
		case ^microui.Command_Clip:
			if v.rect == microui.unclipped_rect {
				raylib.EndScissorMode()
			} else {
				raylib.BeginScissorMode(v.rect.x, v.rect.y, v.rect.w, v.rect.h)
			}
		case ^microui.Command_Rect:
			raylib.DrawRectangle(v.rect.x, v.rect.y, v.rect.w, v.rect.h, raylib.Color{v.color.r, v.color.g, v.color.b, v.color.a})
		case ^microui.Command_Text:
			txt,err := strings.clone_to_cstring(v.str)
			if err != nil {
				panic("Failed to convert to cstring")
			}
			raylib.DrawText(txt, v.pos.x, v.pos.y, FontSize, raylib.Color{v.color.r, v.color.g, v.color.b, v.color.a})
		case ^microui.Command_Icon:
			rect := v.rect
			src := microui.default_atlas[v.id]
			x := rect.x + (rect.w - src.w) / 2;
			y := rect.y + (rect.h - src.h) / 2;
				 raylib.DrawRectangle(rect.x, rect.y, rect.w, rect.h, raylib.Color{v.color.r, v.color.g, v.color.b, v.color.a})
		}
	}
}
