package main

import "ecs"
import "core:fmt"
import "core:time"
import "core:c"
import "core:strings"
import "vendor:raylib"
import "vendor:microui"

FontSize :: 14

GAME_CONFIG: GameConfig
ENABLE_DEBUG := false
FRAME := true

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

setup_windows :: proc(st: ^ecs.Store, cfg: ^GameConfig) {
	game_area_id := ecs.spawn_with(st, []any{
		ecs.new_comp(WindowArea{
			name = "Game",
			color = raylib.SKYBLUE,
			current_area = cfg.GameRectangle,
			ideal_area = cfg.GameRectangle
		})
	})
	game_area := ecs.query_1(st, ^WindowArea)[0]

	ecs.spawn_with(st, []any{
		ecs.new_comp(WindowArea{
			name = "Debug",
			color = raylib.PINK,
			ideal_area = cfg.DebugRectangle,
			current_area = cfg.DebugRectangle
		})
	})

	ecs.spawn_with(st, []any{
		ecs.new_comp(WindowSubArea{
			name = "Battle Area",
			color = raylib.RED,
			parent = game_area,
			get_current = proc(p: Area) -> Area {
				return {10, 30, p.z - 20, p.w * 0.8 - 60}
			},
		})
	})

	ecs.spawn_with(st, []any{
		ecs.new_comp(WindowSubArea{
			name = "Card Area",
			color = raylib.YELLOW,
			parent = game_area,
			get_current = proc(p: Area) -> Area {
				return {p.x+10, p.w * 0.8 - 15, p.z - 20, p.w *0.2}
				},
		})
	})
}

main :: proc() {
	cfg := gen_cfg()
	GAME_CONFIG = cfg

	ctx := &microui.Context{}
	microui.init(ctx)
	ctx.text_width = text_width
	ctx.text_height = text_height

	raylib.InitWindow(i32(cfg.ScreenWidth), i32(cfg.ScreenHeight), "Main Window")
	defer raylib.CloseWindow()

	store := ecs.init_store(5)
	defer ecs.deinit_store(store)

	ecs.register_component(store, ^WindowArea)
	ecs.register_component(store, ^WindowSubArea)

	setup_windows(store, &cfg)

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
			defer { FRAME = !ENABLE_DEBUG || false }
			raylib.ClearBackground(cfg.BackgroundColor)

			dt := f32(frame_start - lastFrameStart) / f32(sec_in_ns)

			// Get user input
			get_input(ctx)

			{
				microui.begin(ctx)
				defer microui.end(ctx)

				windows := ecs.query_1(store, ^WindowArea)
				setup(windows)
				update(windows, dt)
				render(windows)

				sub_windows := ecs.query_1(store, ^WindowSubArea)
				render_subwindows(sub_windows)
			}

			render_microui(ctx)

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
		ENABLE_DEBUG = !ENABLE_DEBUG
	}

	if raylib.IsKeyPressed(.SPACE) {
		FRAME = true
	}
}

render_microui :: proc(ctx: ^microui.Context) {
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

center_text :: proc(msg: cstring, x, y, font_size: c.int, color: raylib.Color) {
	text_width := raylib.MeasureText(msg, font_size)
	raylib.DrawText(msg, x - text_width / 2, y - font_size / 2, font_size, raylib.WHITE)
}
