package reader

import "core:os"
import "core:strings"
import "src:common"

Error :: union #shared_nil {
	STL_Construction_Error,
	Reader_Error,
	os.Error,
}

Reader_Error :: enum {
	None = 0,
	File_Not_Identifiable_Error,
}

read_mesh :: proc(fname: string) -> (common.Mesh, Error) {

	tmp_split := strings.split(fname, ".")
	if len(tmp_split) == 0 {
		return common.Mesh{}, Reader_Error.File_Not_Identifiable_Error
	}
	ext := tmp_split[len(tmp_split) - 1]

	switch (ext) {
	case "stl":
		return read_stl(fname)

	case:
		return common.Mesh{}, Reader_Error.File_Not_Identifiable_Error

	}

	return common.Mesh{}, nil
}

