package viewer

import "src:linalg"

Light :: struct {
	position:  linalg.Vector3,
	direction: linalg.Vector3,
	color:     linalg.Vector4,
}

MakeLight :: proc(position: linalg.Vector3, direction: common.Vector3, color: common.Vector4) -> Light {
	return {position, linalg.normalize_vector(direction), color}
}
