package viewer

ZBuffer :: [SCREEN_WIDTH * SCREEN_HEIGHT]f64

ClearZBuffer :: proc(buf: ^ZBuffer) {
	for &px in buf {
		px = 999_999
	}
}
