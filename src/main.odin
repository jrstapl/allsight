package main

import "core:fmt"
import "core:os"

import "viewer"


main :: proc() {
	proc_name := os.args[0]

	if len(os.args) < 2 || os.args[1][0] == '-' {
		viewer.open_window(os.args[1:])
		os.exit(0)
	}

	// if more than 1 input arg (procname) and the first arg
	// does not start with '-' which would imply a parameter,
	// we should be safe to switch on the first argument as a command


	command := os.args[1]

	switch command {
	case "refine":
		fmt.println("refine!")
	case "register":
		fmt.println("register!")
	case "deviation":
		fmt.println("deviation!")
	case:
		fmt.println(
			"Command not recognized, please pass no command to open the viewer, or one of the following for the CLI:\nrefine\nregister\ndeviation",
		)

	}

	os.exit(0)


}

