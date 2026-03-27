package common

import rl "vendor:raylib"

NGon :: struct {
	points: []Vector3,
	normal: Vector3,
}

Mesh :: struct {
	vertices:  []Vector3,
	faces:     []NGon,
	colors:    []rl.Color,
	pointdata: []f64,
}

calculate_face_normal :: proc {
	calculate_face_normal_points,
	calculate_face_normal_face,
}

calculate_face_normal_points :: proc(p1, p2, p3: Vector3) -> Vector3 {
	v1 := p2 - p1
	v2 := p3 - p1

	return cross_product_normalized(v1, v2)

}

calculate_face_normal_face :: proc(v: [3]Vector3) -> Vector3 {
	return calculate_face_normal_points(v.x, v.y, v.z)

}

