package reader

import "../common"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"

ParseCoord :: proc(split: []string, idx: i32) -> f32 {
	coord, ok := strconv.parse_f32(split[idx])
	if !ok {
		log.panic("Failed to parse coordinate")
	}

	return coord
}
ParseIndices :: proc(split: []string, idx: u8) -> (int, int, int) {
	indices := strings.split(split[idx], "/")

	v, okv := strconv.parse_int(indices[0])
	if !okv {
		log.panic("Failed to parse index of a vertex")
	}

	vt, okvt := strconv.parse_int(indices[1])
	if !okvt {
		log.panic("Failed to parse index of a UV")
	}

	vn, okvn := strconv.parse_int(indices[2])
	if !okvn {
		log.panic("Failed to parse index of a normal")
	}


	return v - 1, vt - 1, vn - 1


}

LoadMeshFromObjFile :: proc(filepath: string) -> common.Mesh {
	data, ok := os.read_entire_file(filepath, context.allocator)

	if ok != nil {
		log.panic("Failed to read file %v", filepath)
	}

	defer delete(data)

	vertices: [dynamic]common.Vector3
	normals: [dynamic]common.Vector3
	triangles: [dynamic]common.NGon
	uvs: [dynamic]common.Vector2

	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		if len(line) <= 0 {
			continue
		}
		if line[0] == '#' {
			continue
		}

		split := strings.split(line, " ")

		switch split[0] {
		case "v":
			x := ParseCoord(split, 1)
			y := ParseCoord(split, 2)
			z := ParseCoord(split, 3)
			append(&vertices, Vector3{x, y, z})
		case "vn":
			nx := ParseCoord(split, 1)
			ny := ParseCoord(split, 2)
			nz := ParseCoord(split, 3)
			append(&normals, Vector3{nx, ny, nz})
		case "vt":
			u := ParseCoord(split, 1)
			v := ParseCoord(split, 2)
			append(&uvs, Vector2{u, v})
		case "f":
			// f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3
			v1, vt1, vn1 := ParseIndices(split, 1)
			v2, vt2, vn2 := ParseIndices(split, 2)
			v3, vt3, vn3 := ParseIndices(split, 3)
			append(&triangles, Triangle{v1, v2, v3, vt1, vt2, vt3, vn1, vn2, vn3})
		}

	}


	return Mesh {
		transformedVertices = make([]Vector3, len(vertices)),
		transformedNormals = make([]Vector3, len(normals)),
		vertices = vertices[:],
		normals = normals[:],
		triangles = triangles[:],
		uvs = uvs[:],
	}
}
