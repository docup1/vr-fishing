@tool
class_name PixelArtRendererPreset
extends Resource

enum DitherMode {
	NONE = 0,
	NOISE = 1,
	BAYER_4X4 = 2,
}

@export var preset_name := "Clean Pixel"
@export_range(16, 4096, 1) var virtual_width := 320
@export_range(16, 4096, 1) var virtual_height := 180
@export_range(1.0, 60.0, 1.0) var target_fps := 12.0
@export_range(2.0, 32.0, 1.0) var color_levels := 7.0
@export_enum("None", "Noise", "Bayer 4x4") var dither_mode: int = DitherMode.NOISE
@export_range(0.0, 1.0, 0.01) var dither_strength := 0.24
@export var outline_enabled := true
@export_range(0.0, 1.0, 0.01) var outline_strength := 0.52
@export_range(0.02, 0.8, 0.01) var outline_threshold := 0.18
