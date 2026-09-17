package viewer

import "core:fmt"
import "core:os"
import "src:linalg"
import "src:reader"
import rl "vendor:raylib"

open_window :: proc(arguments: []string) {

	if len(arguments) < 1 {
		fmt.println("No input file given for viewer")
		os.exit(1)
	}

	filename := arguments[1]

	mesh, err := reader.read_mesh(filename)

	if (err != nil) {
		switch (err) {
		case reader.Reader_Error.File_Not_Identifiable_Error:
			fmt.printf("Filetype not supported:\n%s\n", filename)
		case reader.STL_Construction_Error.Malformed_Facet:
			fmt.println("Error reading Facet")
			fmt.printf("Malformed STL file:\n%s\n", filename)
		case reader.STL_Construction_Error.Malformed_Normal:
			fmt.println("Error reading Normal")
			fmt.printf("Malformed STL file:\n%s\n", filename)
		case reader.STL_Construction_Error.Malformed_Vertex:
			fmt.println("Error reading Vertex")
			fmt.printf("Malformed STL file:\n%s\n", filename)
		case:
			fmt.printf("Unable to read file:\n%s\n", filename)
		}
	}

	perspectiveMatrix := linalg.MakePerspectiveMatrix(FOV, SCREEN_WIDTH, SCREEN_HEIGHT, NEAR_PLANE, FAR_PLANE)
	ambient := linalg.Vector3{0.2, 0.2, 0.2}


	for !rl.WindowShouldClose() {
		rl.BeginDrawing()

		DrawMesh(mesh.vertices, mesh.faces, perspectiveMatrix, zBuffer, ambient)


		rl.EndDrawing()
	}

	rl.CloseWindow()

}

