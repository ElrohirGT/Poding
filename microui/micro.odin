package main

import "core:bytes"
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
		textlen := 10
		buff := [10]u8{}
		microui.textbox(ctx, buff[:], &textlen)
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
		if (len(txt.buf)>0) {
			fmt.printf("Got text! %s\n", txt.buf[:])
		}
		microui.input_text(ctx, strings.to_string(txt^))

		for k := raylib.GetKeyPressed(); k != raylib.KeyboardKey.KEY_NULL; k = raylib.GetKeyPressed() {
			if map_k, ok := map_to_microui_key(k); ok {
				microui.input_key_down(ctx, map_k)
			}
		}

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

map_to_microui_key :: proc(key: raylib.KeyboardKey) -> (microui.Key, bool) {
	a : microui.Key
	#partial switch key {
	case .LEFT_SHIFT: fallthrough
	case .RIGHT_SHIFT:
		a = microui.Key.SHIFT
	case .LEFT_CONTROL: fallthrough
	case .RIGHT_CONTROL:
		a = microui.Key.CTRL
	case .LEFT_ALT: fallthrough
	case .RIGHT_ALT:
		a = microui.Key.ALT
	case .BACKSPACE:
		a = microui.Key.BACKSPACE
	case .DELETE:
		a = microui.Key.DELETE
	case .ENTER:
		a = microui.Key.RETURN
	case .LEFT:
		a = microui.Key.LEFT
	case .RIGHT:
		a = microui.Key.RIGHT
	case .HOME:
		a = microui.Key.HOME
	case .END:
		a = microui.Key.END
	case .A:
		a = microui.Key.A
	case .X:
		a = microui.Key.X
	case .C:
		a = microui.Key.C
	case .V:
		a = microui.Key.V
	case: return a, false
	}
	return a, true
}
