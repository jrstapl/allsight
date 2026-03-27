package common

import "core:math"

Vector3 :: [3]f64
VectorN :: [dynamic]f64

normalize_vector :: proc {
	normalize_vector3,
	normalize_vectorN,
}

normalize_vector3 :: proc(v: Vector3) -> Vector3 {
	mag := math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

	if mag == 0 {
		return Vector3{0, 0, 0}
	}


	return Vector3{v.x / mag, v.y / mag, v.z / mag}

}

normalize_vectorN :: proc(v: VectorN) -> VectorN {
	mag := 0.0
	new_vec := VectorN{}
	reserve(&new_vec, len(v))
	for n in v {
		mag += n * n
		append(&new_vec, n)
	}

	mag = math.sqrt(mag)

	for &n in new_vec {
		n /= mag

	}

	return new_vec
}

dot_product :: proc {
	dot_product_vector3,
}

dot_product_vector3 :: proc(v1, v2: Vector3) -> f64 {
	return v1.x * v2.x + v1.y * v2.y + v1.z + v2.z
}

cross_product :: proc {
	cross_product_vector3,
}

cross_product_vector3 :: proc(v1, v2: Vector3) -> Vector3 {

	return Vector3{v1.y * v2.z - v1.z * v2.y, v1.z * v2.x - v1.x * v2.z, v1.x * v2.y - v1.y * v2.x}

}


cross_product_normalized :: proc {
	cross_product_normalized_vector3,
}

cross_product_normalized_vector3 :: proc(v1, v2: Vector3) -> Vector3 {
	tmp := cross_product_vector3(v1, v2)
	return normalize_vector3(tmp)
}

