package viewer

import "core:math"
import "src:linalg"
import rl "vendor:raylib"

// Coordinate systems
ProjectToScreen :: proc(mat: linalg.Matrix4x4, p: common.Vector3) -> common.Vector3 {
	clip := linalg.Mat4MulVec4(mat, common.Vector4{p.x, p.y, p.z, 1})
	invW: f64 = 1 / clip.w

	ndcX := clip.x * invW
	ndcY := clip.y * invW

	screenX := (ndcX * 0.5 + 0.5) * SCREEN_WIDTH
	screenY := (-ndcY * 0.5 + 0.5) * SCREEN_HEIGHT

	return linalg.Vector3{screenX, screenY, invW}


}

BarycentricWeights :: proc(a, b, c, p: linalg.Vector2) -> common.Vector3 {
	ac := c - a
	ab := b - a
	ap := p - a
	pc := c - p
	pb := b - p

	area := (ac.x * ab.y - ac.y * ab.x)
	alpha := (pc.x * pb.y - pc.y * pb.x) / area
	beta := (ac.x * ap.y - ac.y * ap.x) / area
	gamma := (1.0 - alpha - beta)

	return linalg.Vector3{alpha, beta, gamma}
}

// Optimization checks

IsBackFace :: proc(v1, v2, v3: linalg.Vector3) -> bool {
	edge1 := v2 - v1
	edge2 := v3 - v1
	crossNorm := linalg.cross_product_normalized(edge1, edge2)
	toCamera := linalg.normalize_vector(v1)

	return linalg.dot_product_vector3(crossNorm, toCamera) >= 0.0
}

IsPointOutsideViewport :: proc(x, y: i32) -> bool {
	return x < 0 || x >= SCREEN_WIDTH || y < 0 || y >= SCREEN_HEIGHT
}


IsFaceOutsideFrustum :: proc(p1, p2, p3: linalg.Vector3) -> bool {
	if (p1.z > 1 || p2.z > 1 || p3.z > 1) || (p1.z < -1 || p2.z < -1 || p3.z < -1) {
		return true
	}

	minX := math.min(p1.x, math.min(p2.x, p3.x))
	maxX := math.max(p1.x, math.max(p2.x, p3.x))
	minY := math.min(p1.y, math.min(p2.y, p3.y))
	maxY := math.max(p1.y, math.max(p2.y, p3.y))

	if maxX < 0 || maxY < 0 || maxX > SCREEN_WIDTH || maxY > SCREEN_HEIGHT {
		return true
	}

	return false
}


// Drawing procedures


DrawLine :: proc(a, b: linalg.Vector2, color: rl.Color, image: ^rl.Image) {
	dX := b.x - a.x
	dY := b.y - a.y

	longerDelta := math.abs(dX) >= math.abs(dY) ? math.abs(dX) : math.abs(dY)

	incX := dX / longerDelta
	incY := dY / longerDelta

	x := a.x
	y := a.y

	for i := 0; i <= int(longerDelta); i += 1 {
		rl.ImageDrawPixel(image, i32(x), i32(y), color)
		x += incX
		y += incY
	}

}


DrawPixel :: proc(x, y: f64, p1, p2, p3: ^linalg.Vector3, color: rl.Color, zBuffer: ^ZBuffer, image: ^rl.Image) {
	ix := i32(x)
	iy := i32(y)

	if IsPointOutsideViewport(ix, iy) {
		return
	}

	p := linalg.Vector2{x, y}
	weights := BarycentricWeights(p1.xy, p2.xy, p3.xy, p)
	alpha := weights.x
	beta := weights.y
	gamma := weights.z

	denom := alpha * p1.z + beta * p2.z + gamma * p3.z
	depth := 1.0 / denom

	zIndex := SCREEN_WIDTH * iy + ix
	if (depth < zBuffer[zIndex]) {
		rl.ImageDrawPixel(image, ix, iy, color)
		zBuffer[zIndex] = depth
	}
}

DrawTexelFlatShaded :: proc(
	x, y: f64,
	p1, p2, p3: ^linalg.Vector3,
	uv1, uv2, uv3: ^linalg.Vector2,
	texture: Texture,
	light: linalg.Vector3,
	zBuffer: ^ZBuffer,
	image: ^rl.Image,
) {
	ix := i32(x)
	iy := i32(y)

	if IsPointOutsideViewport(ix, iy) {
		return
	}


	p := linalg.Vector2{x, y}
	weights := BarycentricWeights(p1.xy, p2.xy, p3.xy, p)
	alpha := weights.x
	beta := weights.y
	gamma := weights.z

	denom := alpha * p1.z + beta * p2.z + gamma * p3.z
	depth := 1.0 / denom

	zIndex := SCREEN_WIDTH * iy + ix
	if depth <= zBuffer[zIndex] {
		interpU := ((uv1.x * p1.z) * alpha + (uv2.x * p2.z) * beta + (uv3.x * p3.z) * gamma) * depth
		interpV := ((uv1.y * p1.z) * alpha + (uv2.y * p2.z) * beta + (uv3.y * p3.z) * gamma) * depth

		texX := i32(interpU * f64(texture.width)) % texture.width
		texY := i32(interpV * f64(texture.height)) % texture.height

		tex := texture.pixels[texY * texture.width + texX]

		shadedTex := rl.Color{u8(f64(tex.r) * light.r), u8(f64(tex.g) * light.g), u8(f64(tex.b) * light.b), tex.a}

		rl.ImageDrawPixel(image, ix, iy, shadedTex)
		zBuffer[zIndex] = depth
	}
}

DrawPixelPhongShaded :: proc(
	x, y: f64,
	v1, v2, v3, n1, n2, n3, p1, p2, p3: ^linalg.Vector3,
	color: rl.Color,
	lights: []Light,
	zBuffer: ^ZBuffer,
	image: ^rl.Image,
	ambient: linalg.Vector3,
) {
	ix := i32(x)
	iy := i32(y)

	if IsPointOutsideViewport(ix, iy) {
		return
	}

	p := linalg.Vector2{x, y}
	weights := BarycentricWeights(p1.xy, p2.xy, p3.xy, p)
	alpha := weights.x
	beta := weights.y
	gamma := weights.z

	denom := alpha * p1.z + beta * p2.z + gamma * p3.z
	depth := 1.0 / denom

	zIndex := SCREEN_WIDTH * iy + ix
	if (depth < zBuffer[zIndex]) {
		interpNormal := linalg.normalize_vector3(n1^ * alpha + n2^ * beta + n3^ * gamma)
		interpPos := ((v1^ * p1.z) * alpha + (v2^ * p2.z) * beta + (v3^ * p3.z) * gamma) * depth
		lightAccum := ambient
		for &light in lights {
			lightVec := linalg.normalize_vector3(light.position - interpPos)
			diffuse := math.max(0.0, linalg.dot_product_vector3(interpNormal, lightVec))
			lightAccum.r += diffuse * light.color.r * light.color.a
			lightAccum.g += diffuse * light.color.g * light.color.a
			lightAccum.b += diffuse * light.color.b * light.color.a
		}

		lightAccum.r = math.min(lightAccum.r, 1.0)
		lightAccum.g = math.min(lightAccum.g, 1.0)
		lightAccum.b = math.min(lightAccum.b, 1.0)

		shadedColor := rl.Color {
			u8(f64(color.r) * lightAccum.r),
			u8(f64(color.g) * lightAccum.g),
			u8(f64(color.b) * lightAccum.b),
			color.a,
		}
		rl.ImageDrawPixel(image, ix, iy, shadedColor)
		zBuffer[zIndex] = depth
	}
}

DrawTexelPhongShaded :: proc(
	x, y: f64,
	v1, v2, v3, n1, n2, n3: ^linalg.Vector3,
	uv1, uv2, uv3: ^linalg.Vector2,
	p1, p2, p3: ^linalg.Vector3,
	texture: Texture,
	lights: []Light,
	zBuffer: ^ZBuffer,
	image: ^rl.Image,
	ambient: linalg.Vector3,
) {
	ix := i32(x)
	iy := i32(y)

	if IsPointOutsideViewport(ix, iy) {
		return
	}

	p := linalg.Vector2{x, y}
	weights := BarycentricWeights(p1.xy, p2.xy, p3.xy, p)
	alpha := weights.x
	beta := weights.y
	gamma := weights.z

	denom := alpha * p1.z + beta * p2.z + gamma * p3.z
	depth := 1.0 / denom

	zIndex := SCREEN_WIDTH * iy + ix
	if (depth < zBuffer[zIndex]) {
		interpU := ((uv1.x * p1.z) * alpha + (uv2.x * p2.z) * beta + (uv3.x * p3.z) * gamma) * depth
		interpV := ((uv1.y * p1.z) * alpha + (uv2.y * p2.z) * beta + (uv3.y * p3.z) * gamma) * depth

		texX := i32(interpU * f64(texture.width)) % texture.width
		texY := i32(interpV * f64(texture.height)) % texture.height

		tex := texture.pixels[texY * texture.width + texX]
		interpNormal := linalg.normalize_vector3(n1^ * alpha + n2^ * beta + n3^ * gamma)
		interpPos := ((v1^ * p1.z) * alpha + (v2^ * p2.z) * beta + (v3^ * p3.z) * gamma) * depth
		lightAccum := ambient
		for &light in lights {
			lightVec := linalg.normalize_vector3(light.position - interpPos)
			diffuse := math.max(0.0, linalg.dot_product_vector3(interpNormal, lightVec))
			lightAccum.r += diffuse * light.color.r * light.color.a
			lightAccum.g += diffuse * light.color.g * light.color.a
			lightAccum.b += diffuse * light.color.b * light.color.a
		}

		lightAccum.r = math.min(lightAccum.r, 1.0)
		lightAccum.g = math.min(lightAccum.g, 1.0)
		lightAccum.b = math.min(lightAccum.b, 1.0)

		shadedColor := rl.Color {
			u8(f64(tex.r) * lightAccum.r),
			u8(f64(tex.g) * lightAccum.g),
			u8(f64(tex.b) * lightAccum.b),
			tex.a,
		}
		rl.ImageDrawPixel(image, ix, iy, shadedColor)
		zBuffer[zIndex] = depth
	}
}


DrawFilledTriangle :: proc(p1, p2, p3: ^linalg.Vector3, color: rl.Color, zBuffer: ^ZBuffer, image: ^rl.Image) {
	Sort(p1, p2, p3)
	linalg.floor_xy(p1)
	linalg.floor_xy(p2)
	linalg.floor_xy(p3)

	if p1.y != p2.y {
		invSlope1 := (p2.x - p1.x) / (p2.y - p1.y)
		invSlope2 := (p3.x - p1.x) / (p3.y - p1.y)

		for y := p1.y; y <= p2.y; y += 1 {
			xStart := p1.x + (y - p1.y) * invSlope1
			xEnd := p1.x + (y - p1.y) * invSlope2
			if xStart > xEnd {
				xStart, xEnd = xEnd, xStart
			}
			for x := xStart; x <= xEnd; x += 1 {
				DrawPixel(x, y, p1, p2, p3, color, zBuffer, image)
			}

		}


	}

	if p3.y != p1.y {
		invSlope1 := (p3.x - p2.x) / (p3.y - p2.y)
		invSlope2 := (p3.x - p1.x) / (p3.y - p1.y)


		for y := p2.y; y <= p3.y; y += 1 {
			xStart := p2.x + (y - p2.y) * invSlope1
			xEnd := p1.x + (y - p1.y) * invSlope2

			if xStart > xEnd {
				xStart, xEnd = xEnd, xStart
			}


			for x := xStart; x <= xEnd; x += 1 {
				DrawPixel(x, y, p1, p2, p3, color, zBuffer, image)
			}
		}

	}
}


DrawTexturedTriangleFlatShaded :: proc(
	p1, p2, p3: ^linalg.Vector3,
	uv1, uv2, uv3: ^linalg.Vector2,
	texture: Texture,
	light: linalg.Vector3,
	zBuffer: ^ZBuffer,
	image: ^rl.Image,
) {
	Sort(p1, p2, p3, uv1, uv2, uv3)
	linalg.floor_xy(p1)
	linalg.floor_xy(p2)
	linalg.floor_xy(p3)

	if p1.y != p2.y {
		invSlope1 := (p2.x - p1.x) / (p2.y - p1.y)
		invSlope2 := (p3.x - p1.x) / (p3.y - p1.y)

		for y := p1.y; y <= p2.y; y += 1 {
			xStart := p1.x + (y - p1.y) * invSlope1
			xEnd := p1.x + (y - p1.y) * invSlope2
			if xStart > xEnd {
				xStart, xEnd = xEnd, xStart
			}
			for x := xStart; x <= xEnd; x += 1 {
				DrawTexelFlatShaded(x, y, p1, p2, p3, uv1, uv2, uv3, texture, light, zBuffer, image)
			}

		}


	}

	if p3.y != p1.y {
		invSlope1 := (p3.x - p2.x) / (p3.y - p2.y)
		invSlope2 := (p3.x - p1.x) / (p3.y - p1.y)


		for y := p2.y; y <= p3.y; y += 1 {
			xStart := p2.x + (y - p2.y) * invSlope1
			xEnd := p1.x + (y - p1.y) * invSlope2

			if xStart > xEnd {
				xStart, xEnd = xEnd, xStart
			}


			for x := xStart; x <= xEnd; x += 1 {
				DrawTexelFlatShaded(x, y, p1, p2, p3, uv1, uv2, uv3, texture, light, zBuffer, image)
			}
		}

	}
}

DrawTrianglePhongShaded :: proc(
	v1, v2, v3: ^linalg.Vector3,
	p1, p2, p3: ^linalg.Vector3,
	n1, n2, n3: ^linalg.Vector3,
	color: rl.Color,
	lights: []Light,
	zBuffer: ^ZBuffer,
	image: ^rl.Image,
	ambient: linalg.Vector3,
) {
	Sort(p1, p2, p3, v1, v2, v3)

	linalg.floor_xy(p1)
	linalg.floor_xy(p2)
	linalg.floor_xy(p3)


	if p1.y != p2.y {
		invSlope1 := (p2.x - p1.x) / (p2.y - p1.y)
		invSlope2 := (p3.x - p1.x) / (p3.y - p1.y)

		for y := p1.y; y <= p2.y; y += 1 {
			xStart := p1.x + (y - p1.y) * invSlope1
			xEnd := p1.x + (y - p1.y) * invSlope2
			if xStart > xEnd {
				xStart, xEnd = xEnd, xStart
			}
			for x := xStart; x <= xEnd; x += 1 {
				DrawPixelPhongShaded(x, y, v1, v2, v3, n1, n2, n3, p1, p2, p3, color, lights, zBuffer, image, ambient)
			}

		}


	}

	if p3.y != p1.y {
		invSlope1 := (p3.x - p2.x) / (p3.y - p2.y)
		invSlope2 := (p3.x - p1.x) / (p3.y - p1.y)


		for y := p2.y; y <= p3.y; y += 1 {
			xStart := p2.x + (y - p2.y) * invSlope1
			xEnd := p1.x + (y - p1.y) * invSlope2

			if xStart > xEnd {
				xStart, xEnd = xEnd, xStart
			}


			for x := xStart; x <= xEnd; x += 1 {
				DrawPixelPhongShaded(x, y, v1, v2, v3, n1, n2, n3, p1, p2, p3, color, lights, zBuffer, image, ambient)
			}
		}

	}


}

DrawTexturedTrianglePhongShaded :: proc(
	v1, v2, v3: ^linalg.Vector3,
	p1, p2, p3: ^linalg.Vector3,
	uv1, uv2, uv3: ^linalg.Vector2,
	n1, n2, n3: ^linalg.Vector3,
	texture: Texture,
	lights: []Light,
	zBuffer: ^ZBuffer,
	image: ^rl.Image,
	ambient: linalg.Vector3,
) {
	Sort(p1, p2, p3, uv1, uv2, uv3, v1, v2, v3)

	linalg.floor_xy(p1)
	linalg.floor_xy(p2)
	linalg.floor_xy(p3)


	if p1.y != p2.y {
		invSlope1 := (p2.x - p1.x) / (p2.y - p1.y)
		invSlope2 := (p3.x - p1.x) / (p3.y - p1.y)

		for y := p1.y; y <= p2.y; y += 1 {
			xStart := p1.x + (y - p1.y) * invSlope1
			xEnd := p1.x + (y - p1.y) * invSlope2
			if xStart > xEnd {
				xStart, xEnd = xEnd, xStart
			}
			for x := xStart; x <= xEnd; x += 1 {
				DrawTexelPhongShaded(
					x,
					y,
					v1,
					v2,
					v3,
					n1,
					n2,
					n3,
					uv1,
					uv2,
					uv3,
					p1,
					p2,
					p3,
					texture,
					lights,
					zBuffer,
					image,
					ambient,
				)
			}

		}


	}

	if p3.y != p1.y {
		invSlope1 := (p3.x - p2.x) / (p3.y - p2.y)
		invSlope2 := (p3.x - p1.x) / (p3.y - p1.y)


		for y := p2.y; y <= p3.y; y += 1 {
			xStart := p2.x + (y - p2.y) * invSlope1
			xEnd := p1.x + (y - p1.y) * invSlope2

			if xStart > xEnd {
				xStart, xEnd = xEnd, xStart
			}


			for x := xStart; x <= xEnd; x += 1 {
				DrawTexelPhongShaded(
					x,
					y,
					v1,
					v2,
					v3,
					n1,
					n2,
					n3,
					uv1,
					uv2,
					uv3,
					p1,
					p2,
					p3,
					texture,
					lights,
					zBuffer,
					image,
					ambient,
				)
			}
		}

	}
}


// Drawing modes
DrawWireframe :: proc(
	vertices: []linalg.Vector3,
	triangles: []linalg.Triangle,
	projMat: linalg.Matrix4x4,
	color: rl.Color,
	cullBackFace: bool,
	image: ^rl.Image,
) {
	for &tri in triangles {
		v1 := vertices[tri[0]]
		v2 := vertices[tri[1]]
		v3 := vertices[tri[2]]

		if cullBackFace && IsBackFace(projType, v1, v2, v3) {
			continue
		}


		p1 := ProjectToScreen(projMat, v1)
		p2 := ProjectToScreen(projMat, v2)
		p3 := ProjectToScreen(projMat, v3)

		if (IsFaceOutsideFrustum(p1, p2, p3)) {
			continue
		}

		DrawLine(p1.xy, p2.xy, color, image)
		DrawLine(p2.xy, p3.xy, color, image)
		DrawLine(p3.xy, p1.xy, color, image)

	}
}

DrawUnlit :: proc(
	vertices: []linalg.Vector3,
	triangles: []linalg.Triangle,
	projMat: linalg.Matrix4x4,
	color: rl.Color,
	zBuffer: ^ZBuffer,
	image: ^rl.Image,
) {

	for &tri in triangles {
		v1 := vertices[tri[0]]
		v2 := vertices[tri[1]]
		v3 := vertices[tri[2]]

		if IsBackFace(projType, v1, v2, v3) {
			continue
		}


		p1 := ProjectToScreen(projMat, v1)
		p2 := ProjectToScreen(projMat, v2)
		p3 := ProjectToScreen(projMat, v3)

		if IsFaceOutsideFrustum(p1, p2, p3) {
			continue
		}

		DrawFilledTriangle(&p1, &p2, &p3, color, zBuffer, image)
	}
}

DrawFlatShaded :: proc(
	vertices: []linalg.Vector3,
	triangles: []linalg.Triangle,
	projMat: linalg.Matrix4x4,
	lights: []Light,
	color: rl.Color,
	zBuffer: ^ZBuffer,
	image: ^rl.Image,
	ambient: linalg.Vector3,
) {
	for &tri in triangles {
		v1 := vertices[tri[0]]
		v2 := vertices[tri[1]]
		v3 := vertices[tri[2]]

		crossNorm := linalg.cross_product_normalized_vector3(v2 - v1, v3 - v1)
		toCamera: Vector3
		toCamera = linalg.normalize_vector3(v1)

		if linalg.dot_product_vector3(crossNorm, toCamera) >= 0.0 {
			continue
		}

		p1 := ProjectToScreen(projType, projMat, v1)
		p2 := ProjectToScreen(projType, projMat, v2)
		p3 := ProjectToScreen(projType, projMat, v3)

		if IsFaceOutsideFrustum(p1, p2, p3) {
			continue
		}

		lightAccum := ambient
		for &light in lights {
			diffuse := math.max(0.0, linalg.dot_product_vector3(crossNorm, light.direction))
			lightAccum.r += diffuse * light.color.r * light.color.a
			lightAccum.g += diffuse * light.color.g * light.color.a
			lightAccum.b += diffuse * light.color.b * light.color.a
		}

		lightAccum.r = math.min(lightAccum.r, 1.0)
		lightAccum.g = math.min(lightAccum.g, 1.0)
		lightAccum.b = math.min(lightAccum.b, 1.0)


		shadedColor := rl.Color {
			u8(f64(color.r) * lightAccum.r),
			u8(f64(color.g) * lightAccum.g),
			u8(f64(color.b) * lightAccum.b),
			color.a,
		}

		DrawFilledTriangle(&p1, &p2, &p3, shadedColor, zBuffer, image)
	}
}


DrawTexturedFlatShaded :: proc(
	vertices: []linalg.Vector3,
	triangles: []linalg.Triangle,
	uvs: []linalg.Vector2,
	lights: []Light,
	texture: Texture,
	zBuffer: ^ZBuffer,
	projMat: linalg.Matrix4x4,
	image: ^rl.Image,
	ambient: linalg.Vector3,
) {
	for &tri in triangles {
		v1 := vertices[tri[0]]
		v2 := vertices[tri[1]]
		v3 := vertices[tri[2]]

		uv1 := uvs[tri[3]]
		uv2 := uvs[tri[4]]
		uv3 := uvs[tri[5]]

		crossNorm := linalg.cross_product_normalized_vector3(v2 - v1, v3 - v1)
		toCamera: Vector3
		toCamera = Vector3Normalize(v1)


		if dot_product_vector3(crossNorm, toCamera) >= 0.0 {
			continue
		}

		p1 := ProjectToScreen(projType, projMat, v1)
		p2 := ProjectToScreen(projType, projMat, v2)
		p3 := ProjectToScreen(projType, projMat, v3)

		if IsFaceOutsideFrustum(p1, p2, p3) {
			continue
		}

		lightAccum := ambient
		for &light in lights {
			diffuse := math.max(0.0, dot_product_vector3(crossNorm, light.direction))
			lightAccum.r += diffuse * light.color.r * light.color.a
			lightAccum.g += diffuse * light.color.g * light.color.a
			lightAccum.b += diffuse * light.color.b * light.color.a
		}

		lightAccum.r = math.min(lightAccum.r, 1.0)
		lightAccum.g = math.min(lightAccum.g, 1.0)
		lightAccum.b = math.min(lightAccum.b, 1.0)


		DrawTexturedTriangleFlatShaded(&p1, &p2, &p3, &uv1, &uv2, &uv3, texture, lightAccum, zBuffer, image)

	}
}

DrawTexturedUnlit :: proc(
	vertices: []linalg.Vector3,
	triangles: []linalg.Triangle,
	uvs: []linalg.Vector2,
	texture: Texture,
	zBuffer: ^ZBuffer,
	projMat: linalg.Matrix4x4,
	image: ^rl.Image,
) {
	for &tri in triangles {
		v1 := vertices[tri[0]]
		v2 := vertices[tri[1]]
		v3 := vertices[tri[2]]

		uv1 := uvs[tri[3]]
		uv2 := uvs[tri[4]]
		uv3 := uvs[tri[5]]


		if IsBackFace(v1, v2, v3) {
			continue
		}

		p1 := ProjectToScreen(projMat, v1)
		p2 := ProjectToScreen(projMat, v2)
		p3 := ProjectToScreen(projMat, v3)

		if IsFaceOutsideFrustum(p1, p2, p3) {
			continue
		}


		DrawTexturedTriangleFlatShaded(&p1, &p2, &p3, &uv1, &uv2, &uv3, texture, 1.0, zBuffer, image)

	}
}

DrawPhongShaded :: proc(
	vertices: []linalg.Vector3,
	triangles: []linalg.Triangle,
	normals: []linalg.Vector3,
	lights: []Light,
	color: rl.Color,
	zBuffer: ^ZBuffer,
	projMat: linalg.Matrix4x4,
	image: ^rl.Image,
	ambient: linalg.Vector3,
) {

	for &tri in triangles {
		v1 := vertices[tri[0]]
		v2 := vertices[tri[1]]
		v3 := vertices[tri[2]]

		n1 := normals[tri[6]]
		n2 := normals[tri[7]]
		n3 := normals[tri[8]]


		if IsBackFace(projType, v1, v2, v3) {
			continue
		}

		p1 := ProjectToScreen(projMat, v1)
		p2 := ProjectToScreen(projMat, v2)
		p3 := ProjectToScreen(projMat, v3)

		if IsFaceOutsideFrustum(p1, p2, p3) {
			continue
		}


		DrawTrianglePhongShaded(&v1, &v2, &v3, &p1, &p2, &p3, &n1, &n2, &n3, color, lights, zBuffer, image, ambient)
	}
}

DrawTexturedPhongShaded :: proc(
	vertices: []linalg.Vector3,
	triangles: []linalg.Triangle,
	uvs: []linalg.Vector2,
	normals: []linalg.Vector3,
	lights: []Light,
	texture: Texture,
	zBuffer: ^ZBuffer,
	projMat: linalg.Matrix4x4,
	image: ^rl.Image,
	ambient: linalg.Vector3,
) {

	for &tri in triangles {
		v1 := vertices[tri[0]]
		v2 := vertices[tri[1]]
		v3 := vertices[tri[2]]

		uv1 := uvs[tri[3]]
		uv2 := uvs[tri[4]]
		uv3 := uvs[tri[5]]

		n1 := normals[tri[6]]
		n2 := normals[tri[7]]
		n3 := normals[tri[8]]


		if IsBackFace(projType, v1, v2, v3) {
			continue
		}

		p1 := ProjectToScreen(projMat, v1)
		p2 := ProjectToScreen(projMat, v2)
		p3 := ProjectToScreen(projMat, v3)

		if IsFaceOutsideFrustum(p1, p2, p3) {
			continue
		}


		DrawTexturedTrianglePhongShaded(
			&v1,
			&v2,
			&v3,
			&p1,
			&p2,
			&p3,
			&uv1,
			&uv2,
			&uv3,
			&n1,
			&n2,
			&n3,
			texture,
			lights,
			zBuffer,
			image,
			ambient,
		)
	}
}
