package viewer

import "src:common"

Light :: struct {
	position:  common.Vector3,
	direction: common.Vector3,
	color:     common.Vector4,
}

MakeLight :: proc(position: common.Vector3, direction: common.Vector3, color: common.Vector4) -> Light {
	return {position, common.normalize_vector(direction), color}
}
