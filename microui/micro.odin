package main

import "core:fmt"
import "core:strings"
import "vendor:raylib"
import "vendor:microui"

FontSize ::  25

test_window :: proc(ctx: ^microui.Context) {
	window_width :i32 = 300
	window_height :i32 = 240
	if (microui.begin_window(ctx, "Debug window 1", microui.Rect{350, 250, window_width, window_height})) {
		defer microui.end_window(ctx)

		microui.label(ctx, "Sample Label!")
		if (microui.button(ctx, "Press!") == {.SUBMIT}) {
			fmt.println("Pressed!")
		}
	}
}

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
	ctx := new(microui.Context)
	microui.init(ctx)
	ctx.text_width = text_width
	ctx.text_height = text_height

	raylib.InitWindow(800, 600, "Microui Testing!")

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		defer raylib.EndDrawing()

		raylib.ClearBackground(raylib.BLACK)

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

		txt := &strings.Builder{}
		strings.builder_init(txt)
		for ch := raylib.GetCharPressed(); ch != 0; ch = raylib.GetCharPressed() {
			fmt.sbprintf(txt, "%c", ch)
		}
		microui.input_text(ctx, strings.to_string(txt^))

		process_frame(ctx)

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
}

process_frame ::proc(ctx: ^microui.Context){
	microui.begin(ctx)
	defer microui.end(ctx)
	test_window(ctx)
}
