package common

import "core:math"

Matrix4x4 :: [4][4]f32


Mat4MulVec3 :: proc(mat: Matrix4x4, vec: Vector3) -> Vector3 {
	x := (vec.x * mat[0][0]) + (vec.y * mat[0][1]) + (vec.z * mat[0][2]) + (mat[0][3])
	y := (vec.x * mat[1][0]) + (vec.y * mat[1][1]) + (vec.z * mat[1][2]) + (mat[1][3])
	z := (vec.x * mat[2][0]) + (vec.y * mat[2][1]) + (vec.z * mat[2][2]) + (mat[2][3])

	return Vector3{x, y, z}
}

Mat4MulVec4 :: proc(mat: Matrix4x4, vec: Vector4) -> Vector4 {
	x := (vec.x * mat[0][0]) + (vec.y * mat[0][1]) + (vec.z * mat[0][2]) + (vec.w * mat[0][3])
	y := (vec.x * mat[1][0]) + (vec.y * mat[1][1]) + (vec.z * mat[1][2]) + (vec.w * mat[1][3])
	z := (vec.x * mat[2][0]) + (vec.y * mat[2][1]) + (vec.z * mat[2][2]) + (vec.w * mat[2][3])
	w := (vec.x * mat[3][0]) + (vec.y * mat[3][1]) + (vec.z * mat[3][2]) + (vec.w * mat[3][3])

	return Vector4{x, y, z, w}
}


Mat4Mul :: proc(a, b: Matrix4x4) -> (result: Matrix4x4) {
	for i in 0 ..< 4 {
		for j in 0 ..< 4 {
			result[i][j] = a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]

		}
	}
	return
}

MakeTranslationMatrix :: proc(x, y, z: f32) -> Matrix4x4 {


	return Matrix4x4{{1.0, 0.0, 0.0, x}, {0.0, 1.0, 0.0, y}, {0.0, 0.0, 1.0, z}, {0.0, 0.0, 0.0, 1.0}}

}


MakeScaleMatrix :: proc(sx, sy, sz: f32) -> Matrix4x4 {
	return Matrix4x4{{sx, 0.0, 0.0, 0.0}, {0.0, sy, 0.0, 0.0}, {0.0, 0.0, sz, 0.0}, {0.0, 0.0, 0.0, 1.0}}
}

MakeRotationMatrix :: proc(pitch, yaw, roll: f32) -> Matrix4x4 {
	alpha := yaw * DEG_TO_RAD
	beta := pitch * DEG_TO_RAD
	gamma := roll * DEG_TO_RAD

	cos_alpha := math.cos(alpha)
	sin_alpha := math.sin(alpha)


	cos_beta := math.cos(beta)
	sin_beta := math.sin(beta)

	cos_gamma := math.cos(gamma)
	sin_gamma := math.sin(gamma)


	return Matrix4x4 {
		{
			cos_alpha * cos_beta,
			(cos_alpha * sin_beta * sin_gamma) - (sin_alpha * cos_gamma),
			(cos_alpha * sin_beta * cos_gamma) + (sin_alpha * sin_gamma),
			0.0,
		},
		{
			sin_alpha * cos_beta,
			(sin_alpha * sin_beta * sin_gamma) + (cos_alpha * cos_gamma),
			(sin_alpha * sin_beta * cos_gamma) - (cos_alpha * sin_gamma),
			0.0,
		},
		{-sin_beta, cos_beta * sin_gamma, cos_beta * cos_gamma, 0.0},
		{0.0, 0.0, 0.0, 1.0},
	}
}


MakeViewMatrix :: proc(eye: Vector3, target: Vector3) -> Matrix4x4 {
	forward := Vector3Normalize(eye - target)
	right := Vector3CrossProduct(Vector3{0.0, 1.0, 0.0}, forward)
	up := Vector3CrossProduct(forward, right)


	return Matrix4x4 {
		{right.x, right.y, right.z, -Vector3DotProduct(right, eye)},
		{up.x, up.y, up.z, -Vector3DotProduct(up, eye)},
		{forward.x, forward.y, forward.z, -Vector3DotProduct(forward, eye)},
		{0, 0, 0, 1},
	}

}

MakePerspectiveMatrix :: proc(fov: f32, screenWidth: i32, screenHeight: i32, near: f32, far: f32) -> Matrix4x4 {
	f := 1.0 / math.tan_f32(fov * 0.5 * DEG_TO_RAD)
	aspect := f32(screenWidth) / f32(screenHeight)

	return Matrix4x4 {
		{f / aspect, 0, 0, 0},
		{0, f, 0, 0},
		{0, 0, -far / (far - near), -1},
		{0, 0, (-far * near) / (far - near), 0},
	}
}

MakeOrthographicMatrix :: proc(screenWidth: i32, screenHeight: i32, near: f32, far: f32) -> Matrix4x4 {
	aspect := f32(screenWidth) / f32(screenHeight)
	left := -aspect
	right := +aspect
	bottom :: -1.0
	top :: +1.0
	return Matrix4x4 {
		{2 / (right - left), 0, 0, -(right + left) / (right - left)},
		{0, 2 / (top - bottom), 0, -(top + bottom) / (top - bottom)},
		{0, 0, -2 / (far - near), -(far + near) / (far - near)},
		{0, 0, 0, 1},
	}
}
