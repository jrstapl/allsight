package reader

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

import "../common"

Error :: union #shared_nil {
	STL_Construction_Error,
	os.Error,
}

STL_Construction_Error :: enum {
	None = 0,
	Malformed_Facet,
	Malformed_Normal,
	Malformed_Vertex,
}

read_stl :: proc(fp: string) -> (common.Mesh, Error) {

	data, err := os.read_entire_file(fp, context.allocator)
	if err != nil {

		return common.Mesh{}, err
	}
	defer delete(data)

	/* Unfortunately, there seems to be little in the way of differentiation between 
	binary and ascii files, with the best methods being to check if the file starts 
	with 'solid' or not, though binary files could in theory start with solid. A 
	(slightly) more	robust method is offered by checking the end of the file for 'endsolid'
	in addition to starting with solid. This is unfortunately not standardized, and VTK, for 
	example, just checks for solid, tries to read as ascii and then falls back to binary if that 
	fails. It seems like the best approach to just use the 'endsolid' check in addition for ascii, 
	since the binary format _should not_, in theory, contain either, and then let the user know the 
	STL is potentially malformed if the ascii read does not go well*/

	if (strings.starts_with(strings.to_lower(string(data[0:5])), "solid") &&
		   strings.ends_with(
			   strings.trim_space(strings.to_lower(string(data[len(data) - 20:len(data) - 1]))),
			   "endsolid",
		   )) {
		mesh, ascii_err := read_ascii_stl(data)
		if ascii_err != nil {
			return common.Mesh{}, ascii_err

		}

		return mesh, nil


	} else {
		mesh, bin_err := read_binary_stl(data)
		if bin_err != nil || true {
			fmt.println("Binary STL reader not yet implemented...")
			return common.Mesh{}, bin_err
		}
		return mesh, nil
	}

	return common.Mesh{}, nil

}


read_binary_stl :: proc(data: []byte) -> (common.Mesh, Error) {
	return common.Mesh{}, nil

}

/*

solid
 facet normal float float float 
  outer loop
   vertex float float float 
   vertex float float float 
   vertex float float float 
  endloop
 endfacet
 ...
endsolid

*/

read_ascii_stl :: proc(data: []byte) -> (common.Mesh, Error) {
	vertices: [dynamic]common.Vector3
	faces: [dynamic][3]int // STL should be a triangle, until we error otherwise we will assume each face has 3 points
	normals: [dynamic]common.Vector3

	current_vertex_id: u32 = 0
	current_face_id: u32 = 0
	calculate_normal := false


	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		stripped_line := strings.to_lower(strings.trim_space(line))
		all_ok := true

		if len(stripped_line) <= 0 {
			continue
		}
		// maybe not the most efficient checks, could implement a
		// bool to say whether or not to do these checks or something
		if strings.starts_with(stripped_line, "solid") {
			continue
		}
		if strings.starts_with(stripped_line, "endsolid") {
			break
		}

		components := strings.split(stripped_line, " ")

		switch components[0] {
		case "facet":
			x, y, z: f64
			ok: bool
			// use all ok to provide continuity of failure of any vertex conversion

			if len(components) == 5 {
				// components [1] is "normal"
				x, ok = strconv.parse_f64(components[2])
				all_ok = all_ok && ok
				y, ok = strconv.parse_f64(components[3])
				all_ok = all_ok && ok
				z, ok = strconv.parse_f64(components[4])
				all_ok = all_ok && ok

			} else if len(components) == 4 {
				x, ok = strconv.parse_f64(components[1])
				all_ok = all_ok && ok
				y, ok = strconv.parse_f64(components[1])
				all_ok = all_ok && ok
				z, ok = strconv.parse_f64(components[3])
				all_ok = all_ok && ok

			} else if len(components) == 1 {
				calculate_normal = true

			} else {
				return common.Mesh{}, STL_Construction_Error.Malformed_Normal
			}

			if !all_ok {
				return common.Mesh{}, STL_Construction_Error.Malformed_Facet
			}

			append(&normals, common.Vector3{x, y, z})

		case "vertex":
			x, y, z: f64
			ok: bool
			if len(components) == 4 {
				x, ok = strconv.parse_f64(components[1])
				all_ok = all_ok && ok
				y, ok = strconv.parse_f64(components[1])
				all_ok = all_ok && ok
				z, ok = strconv.parse_f64(components[3])
				all_ok = all_ok && ok


			} else {
				return common.Mesh{}, STL_Construction_Error.Malformed_Vertex
			}

			p := common.Vector3{x, y, z}
			add_point := true
			for point, idx in vertices {
				if point == p {
					add_point = false
					break
				}
			}

			if add_point {
				append(&vertices, p)
			}

		case "endfacet":
			current_face_id += 1
			if calculate_normal {
				norm := common.calculate_face_normal(
					vertices[current_vertex_id - 2],
					vertices[current_vertex_id - 1],
					vertices[current_vertex_id],
				)

				append(&normals, norm)
				calculate_normal = false

			}
		}


	}

	return common.Mesh{}, nil

}

