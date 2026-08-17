package main

gen_cfg :: proc() -> GameConfig {
	cfg := GameConfig{
    ScreenWidth = 1080,
    ScreenHeight = 720,
    FpsCap = 60,
		BackgroundColor = {74,88,89,255},
	}
	cfg.GameRectangle = {0, 0, f32(cfg.ScreenWidth) * 3 / 4, f32(cfg.ScreenHeight)}
	cfg.DebugRectangle = {f32(cfg.ScreenWidth) * 3 / 4, 0, f32(cfg.ScreenWidth) / 4, f32(cfg.ScreenHeight)}
	return cfg
}
