package main

import "vendor:microui"

main :: proc() {
	ctx := new(microui.Context)
	microui.init(ctx)
	microui.begin_window(ctx, "Hello!")
}
