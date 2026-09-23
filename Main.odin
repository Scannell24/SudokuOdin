package main

import "core:encoding/csv"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:unicode/utf8"

SQ_SIZE : int : 3
BOARD_SIZE : int : SQ_SIZE * SQ_SIZE
board: [][]rune
board_pot: [][][dynamic]rune // potential values for board cells

Position :: struct {
    x: int,
    y: int,
}

read_sudoku_csv :: proc(csv_path : string) -> (result: [][]rune, ok:=true) {
	records : [][]rune
    data, err := os.read_entire_file(csv_path, context.allocator)
    if err != nil { return records, false}
    defer delete(data, context.allocator)

    // Parse CSV data
    r: csv.Reader
    r.trim_leading_space = true
    defer csv.reader_destroy(&r)
    csv.reader_init_with_string(&r, string(data))

    csv_records, _ := csv.read_all(&r)
    defer delete(csv_records)

	// Instantiate the boards
	length := len(csv_records)
	records = make([][]rune, length)
	board_pot = make([][][dynamic]rune, length)
	for x in 0..<length {
        // Allocate the secondary slice of length N for each element
        board_pot[x] = make([] [dynamic]rune, length)

		for y in 0..<length {
            // Initialize the innermost dynamic array
            board_pot[x][y] = make([dynamic]rune)
		}
	}
	fmt.println("len(board_pot): ", len(board_pot))
	

	for row, i in csv_records {
		rune_row := make([]rune, len(row))
		//fmt.println(row)
		for col, j in row {
			// Convert each string field to a []rune and assign it
			rune_row[j], _ = utf8.decode_rune_in_string(col)
		}
		records[i] = rune_row
	}
	
	return records, ok
}

update_board_pot :: proc(reset:=false) -> (ok:=true) {
	potential_runes : [dynamic]rune
	neighbors : [dynamic]rune
	for x in 0..<BOARD_SIZE {
		for y in 0..<BOARD_SIZE {
			pos := Position{x, y}
			if board[x][y] == '.' {
				potential_runes, ok = get_possible_values(pos)
				if reset {
					board_pot[x][y] = potential_runes
				} else {
					tmp_runes : [dynamic]rune
					for pot_rune in potential_runes {
						_, in_old_pot := slice.linear_search(board_pot[x][y][:], pot_rune)
						if in_old_pot{
							append(&tmp_runes, pot_rune)
						}
					}
					board_pot[x][y] = tmp_runes
				}
			}
		}
	}
	return ok
}

print_sudoku_board_pot :: proc() {
	fmt.println("print_sudoku_board_pot")


	print_line_separator :: proc() {
		fmt.print("+ - - - + - - - + - - - +")
		fmt.print("+ - - - + - - - + - - - +")
		fmt.print("+ - - - + - - - + - - - +")
		fmt.println()
	}

	fmt.println()
	print_line_separator()
	print_line_separator()
	for a in 0..<SQ_SIZE {
		for b in 0..<SQ_SIZE {
			for w in 0..<SQ_SIZE {
				for x in 0..<SQ_SIZE {
					for y in 0..<SQ_SIZE {
						fmt.print('|')
						for z in 0..<SQ_SIZE {
							board_val := board[a*SQ_SIZE+b][x*SQ_SIZE+y]
							if board_val != '.'
							{
								if z == 1 && w == 1 {
									fmt.print("", board_val)
								} else {
									fmt.print("", ' ')
								}
							} else {
								cell_val := rune(w*SQ_SIZE+z+1 + '0')
								_, found := slice.linear_search(board_pot[a*SQ_SIZE+b][x*SQ_SIZE+y][:], cell_val)
								if found
								{
									fmt.print("", cell_val)
								} else {
									fmt.print("", '.')
								}
							}
						}
						fmt.print(" ")
					}
					fmt.print("|")
				}
				fmt.println()
			}
			print_line_separator()
		}
		print_line_separator()
	}
	fmt.println()
}

print_sudoku_board :: proc() {
	fmt.println()
	total_filled := 0
	fmt.println("+ - - - + - - - + - - - +")
	for w in 0..<SQ_SIZE {
		for x in 0..<SQ_SIZE {
			for y in 0..<SQ_SIZE {
				fmt.print('|')
				for z in 0..<SQ_SIZE {
					temp_val := board[w*SQ_SIZE+x][y*SQ_SIZE+z]
					fmt.print("", temp_val)
					if temp_val != '.'
					{
						total_filled += 1
					}
				}
				fmt.print(" ")
			}
			fmt.println('|')
		}
		fmt.println("+ - - - + - - - + - - - +")
	}
	fmt.println()
	fmt.println(total_filled, "/", BOARD_SIZE*BOARD_SIZE)
}

del_potential_vals :: proc(
	row: int,
	col: int,
	rune_slice: [dynamic]rune
) -> (num_del:int, ok:=true) {
	//fmt.println("rune_slice", rune_slice)
	new_rune_slice: [dynamic]rune
	for pot_rune in board_pot[row][col] {
		_, found := slice.linear_search(rune_slice[:], pot_rune)
		if !found {
			append(&new_rune_slice, pot_rune)
		}
	}
	num_del = len(board_pot[row][col]) - len(new_rune_slice)
	board_pot[row][col] = new_rune_slice
	if len(new_rune_slice) == 1 {
		board[row][col] = new_rune_slice[0]
		pop(&board_pot[row][col])
	}
	return num_del, ok
}

find_hidden_pairs_in_boxes :: proc() -> (ok:=true) {
	for i in 0..<SQ_SIZE {
		for j in 0..<SQ_SIZE {
			ok = find_hidden_pairs_in_box(i, j)
		}
	}
	return ok
}

find_hidden_pairs_in_box :: proc(x: int, y: int, dbg_log:=false) -> (ok: bool) {
	pot_runes : [dynamic]rune
	rune_map : [SQ_SIZE][SQ_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int
	rune_pair : [2]rune
	rune_indices : [2]int
	if dbg_log{ fmt.println("box:", x, ",", y) }


	for i in 0..<BOARD_SIZE-1 {
		pos := Position{(SQ_SIZE * x) + i/3, (SQ_SIZE * y) + i%%3}
		pot := board_pot[pos.x][pos.y][:]
		if dbg_log{ fmt.println("pot:", pot) }
	}

	//*
	for i in 0..<BOARD_SIZE {
		pos1 := Position{(SQ_SIZE * x) + i/3, (SQ_SIZE * y) + i%%3}
		pot1 := board_pot[pos1.x][pos1.y][:]
		if dbg_log{ fmt.println("pos1:", pos1) }
		for j in i+1..<BOARD_SIZE {
			pos2 := Position{(SQ_SIZE * x) + j/3, (SQ_SIZE * y) + j%%3}
			if dbg_log{ fmt.println("pos2:", pos2) }
			are_equal := slice.equal(pot1, board_pot[pos2.x][pos2.y][:])
			if are_equal && len(pot1) == 2 {
				fmt.println("pair found! ", pos1, " , ", pos2, ": values", pot1)
				if dbg_log {
					fmt.println("pair found!")
					fmt.println(pos1, ": ", board_pot[pos1.x][pos1.y][:])
					fmt.println(pos2, ": ", board_pot[pos2.x][pos2.y][:])
				}
				for z in 0..<BOARD_SIZE {
					if dbg_log{ fmt.println("z:", z) }
					if i != z && j != z {
						pos := Position{(SQ_SIZE * x) + z/3, (SQ_SIZE * y) + z%%3}
						if dbg_log{ fmt.println(pos) }
						del_potential_vals(pos.x, pos.y, board_pot[pos1.x][pos1.y])
					}
				}

			}
		}
		if dbg_log{ fmt.println() }
	}
	// */
	found := false
	return true
}

find_hidden_pairs_in_rows :: proc() -> (ok:=true) {
	rune_slice : [BOARD_SIZE][dynamic]rune
	rune_pair : [2]rune
	rune_indices : [2]int
	for x in 0..<BOARD_SIZE {
		for i in 0..<BOARD_SIZE {
			//fmt.println("i: ", i)
			if len(board_pot[x][i]) > 0 {
				for j in i+1..<BOARD_SIZE {
					//fmt.print(j, " ")
					if len(board_pot[x][j]) == 2 {
						are_equal := slice.equal(board_pot[x][i][:], board_pot[x][j][:])
						if are_equal {
							fmt.println("pair found! row [", x, "] cols [", i, ",", j, "]: values", board_pot[x][i])
							for z in 0..<BOARD_SIZE {
								if i != z && j != z {
									del_potential_vals(x, z, board_pot[x][i])
								}
							}
						}
					}
				}
			}
		}
	}
	return ok
}

find_hidden_pairs_in_cols :: proc() -> (ok:=true) {
	rune_slice : [BOARD_SIZE][dynamic]rune
	rune_pair : [2]rune
	rune_indices : [2]int
	for x in 0..<BOARD_SIZE {
		for i in 0..<BOARD_SIZE {
			//fmt.println("i: ", i)
			if len(board_pot[i][x]) > 0 {
				for j in i+1..<BOARD_SIZE {
					//fmt.print(j, " ")
					if len(board_pot[j][x]) == 2 {
						are_equal := slice.equal(board_pot[i][x][:], board_pot[j][x][:])
						if are_equal {
							fmt.println("pair found! col [", x, "] rows [", i, ",", j, "]: values", board_pot[i][x])
							for z in 0..<BOARD_SIZE {
								if i != z && j != z {
									del_potential_vals(z, x, board_pot[i][x])
								}
							}
						}
					}
				}
			}
		}
	}
	return ok
}

is_subset :: proc(
	slice1: [dynamic]rune,
	slice2: [dynamic]rune
) -> (is_subset: bool, ok:=true) {
	if len(slice1) > len(slice2) {
		return false, ok
	}
	if slice.equal(slice1[:], slice2[:]) {
		return true, ok
	}
	for rune1 in slice1 {
		_, found := slice.linear_search(slice2[:], rune1)
		if !found {
			return false, ok
		}
	}
	return true, ok
}

find_hidden_sets_in_boxes :: proc(progress:=false) -> (ok:=true) {
	found := false
	for i in 0..<SQ_SIZE {
		for j in 0..<SQ_SIZE {
			found, ok = find_hidden_sets_in_box(i, j)
		}
	}
	return ok
}

find_hidden_sets_in_box :: proc(
		x: int,
		y: int,
		dbg_log:=false
	) -> (set_found:=false, ok:=true) {

	// Look for sets of size 3 or 4 (no need for 5 or 6 as they're compliments)
	for set_size in 3..<5 {
		if dbg_log { fmt.println("set_size: ", set_size) }
		// For each box, go through each cell
		for box_index1 in 0..<BOARD_SIZE {
			box_cell1 := Position{(SQ_SIZE * x) + box_index1/3, (SQ_SIZE * y) + box_index1%%3}
			// If the current cell has the set size we're looking for
			if len(board_pot[box_cell1.x][box_cell1.y]) == set_size {
				// Create dynamic slices to hold indices of interest
				box_cells : [dynamic]int
				append(&box_cells, box_index1)
				if dbg_log { fmt.println("set:", board_pot[box_cell1.x][box_cell1.y]) }
				// Go through this row again
				for box_index2 in 0..<BOARD_SIZE {
					box_cell2 := Position{(SQ_SIZE * x) + box_index2/3, (SQ_SIZE * y) + box_index2%%3}
					// If the row index is not the row of interest and there are potential values
					if box_index1 != box_index2 && len(board_pot[box_cell2.x][box_cell2.y]) > 0 {
						is_subset, ok := is_subset(board_pot[box_cell2.x][box_cell2.y], board_pot[box_cell1.x][box_cell1.y])
						// Add it to the box_cells slice
						if is_subset {
							append(&box_cells, box_index2)
							if dbg_log { fmt.println("subset:", board_pot[box_cell2.x][box_cell2.y]) }
						}
					}
				}
				//*
				if len(box_cells) >= set_size {
					if dbg_log { fmt.println("box_cells:", box_cells) }
					set_found = true
					// Go through the row again
					for box_index3 in 0..<BOARD_SIZE {
						box_cell3 := Position{(SQ_SIZE * x) + box_index3/3, (SQ_SIZE * y) + box_index3%%3}
						_, found := slice.linear_search(box_cells[:], box_index3)
						// If this is not one of the indices of interest and there are multiple potential values
						if !found && len(board_pot[box_cell1.x][box_cell1.y]) > 2 {
							// delete the any values from the set from this cell
							del_potential_vals(box_cell3.x, box_cell3.y, board_pot[box_cell1.x][box_cell1.y])
						}
					}
				}
				//*/
			}
		}
	}
	return set_found, ok
}

find_hidden_sets_in_cols :: proc(dbg_log:=false) -> (set_found:=false, ok:=true) {
	// Look for sets of size 3 or 4 (no need for 5 or 6 as they're compliments)
	for set_size in 3..<5 {
		if dbg_log { fmt.println("set_size: ", set_size) }
		// Go through each column
		for col_y in 0..<BOARD_SIZE {
			// For each column, go through each row
			for row_x1 in 0..<BOARD_SIZE {
				// If the current cell has the set size we're looking for
				if len(board_pot[row_x1][col_y]) == set_size {
					// Create dynamic slices to hold indices of interest
					row_indices : [dynamic]int
					append(&row_indices, row_x1)
					if dbg_log { fmt.println("set:", board_pot[row_x1][col_y]) }
					// Go through this row again
					for row_x2 in 0..<BOARD_SIZE {
						// If the row index is not the row of interest and there are potential values
						if row_x1 != row_x2 && len(board_pot[row_x2][col_y]) > 0 {
							is_subset, ok := is_subset(board_pot[row_x2][col_y], board_pot[row_x1][col_y])
							// Add it to the row_indices slice
							if is_subset {
								append(&row_indices, row_x2)
								if dbg_log { fmt.println("subset:", board_pot[row_x2][col_y]) }
							}
						}
					}
					if len(row_indices) >= set_size {
						if dbg_log { fmt.println("row_indices:", row_indices) }
						set_found = true
						// Go through the row again
						for row_x3 in 0..<BOARD_SIZE {
							_, found := slice.linear_search(row_indices[:], row_x3)
							// If this is not one of the indices of interest and there are multiple potential values
							if !found && len(board_pot[row_x1][col_y]) > 2 {
								// delete the any values from the set from this cell
								del_potential_vals(row_x3, col_y, board_pot[row_x1][col_y])
							}
						}
					}
				}
			}
		}
	}
	return set_found, ok
}

find_hidden_sets_in_rows :: proc(progress_made:^bool, dbg_log:=false) -> (ok:=true) {
	// Look for sets of size 3 or 4 (no need for 5 or 6 as they're compliments)
	for set_size in 3..<5 {
		if dbg_log { fmt.println("set_size: ", set_size) }
		// Go through each row
		for row_x in 0..<BOARD_SIZE {
			// For each row, go through each column
			for col_y1 in 0..<BOARD_SIZE {
				// If the current cell has the set size we're looking for
				if len(board_pot[row_x][col_y1]) == set_size {
					// Create dynamic slices to hold indices of interest
					col_indices : [dynamic]int
					append(&col_indices, col_y1)
					if dbg_log { fmt.println("set:", board_pot[row_x][col_y1]) }
					// Go through this row again
					for col_y2 in 0..<BOARD_SIZE {
						// If the col index is not the col of interest and there are potential values
						if col_y1 != col_y2 && len(board_pot[row_x][col_y2]) > 0 {
							is_subset, ok := is_subset(board_pot[row_x][col_y2], board_pot[row_x][col_y1])
							// Add it to the row_indices slice
							if is_subset {
								append(&col_indices, col_y2)
								if dbg_log { fmt.println("subset:", board_pot[row_x][col_y2]) }
							}
						}
					}
					if len(col_indices) >= set_size {
						if dbg_log { fmt.println("col_indices:", col_indices) }
						// Go through the column again
						for col_y3 in 0..<BOARD_SIZE {
							_, found := slice.linear_search(col_indices[:], col_y3)
							// If this is not one of the indices of interest and there are multiple potential values
							if !found && len(board_pot[row_x][col_y3]) > 2 {
								// delete the any values from the set from this cell
								tmp_copy := board_pot[row_x][col_y3][:]
								num_del, _ := del_potential_vals(row_x, col_y3, board_pot[row_x][col_y1])
								if num_del > 1 {
									if true {
										fmt.println("num_del:", num_del)
										fmt.println("board_pot[row_x][col_y3]:", tmp_copy)
									}
									progress_made^ = true
								}
							}
						}
					}
				}
			}
		}
	}
	return ok
}


check_for_loners :: proc(dbg_log:=false) -> (val_found:=false, ok:=true) {
	loner_in_box, box_ok := check_for_loners_in_boxes()
	loner_in_col, col_ok := check_for_loners_in_columns()
	loner_in_row, row_ok := check_for_loners_in_rows()
	ok = box_ok || col_ok || row_ok
	val_found = loner_in_box || loner_in_col || loner_in_row
	return val_found, ok
}

check_for_loners_in_rows :: proc(dbg_log:=false) ->
(val_found:=false, ok:=true) {
	pot_runes : [dynamic]rune
	rune_slice : [BOARD_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int

	for i in 0..<BOARD_SIZE {
		if dbg_log { fmt.println("row:", i) }
		for j in 0..<BOARD_SIZE {
			rune_counter[j] = 0
		}
		for j in 0..<BOARD_SIZE {
			pos := Position{i, j}
			pot_runes, ok = get_possible_values(pos)
			for pot_rune in pot_runes {
				if dbg_log { fmt.print(pot_rune) }
				index := int(pot_rune - '0')
				if dbg_log { fmt.print(index, ' ') }
				rune_counter[index-1] += 1
			}
			rune_slice[j] = pot_runes
			
		}
		if dbg_log { 
			fmt.println("rune_counter:", rune_counter)
			fmt.println("rune_slice:", rune_slice)
		}

		found := false
		for x in 0..<BOARD_SIZE {
			if rune_counter[x] == 1 {
				curr_rune := rune(x+1 + '0')
				for j in 0..<BOARD_SIZE {
					_, found = slice.linear_search(rune_slice[j][:], curr_rune)
					if found {
						val_found = true
						pos := Position{i, j}
						fmt.println("check_for_loners_in_rows - value for [", pos.x, "][", pos.y, "] determind:", curr_rune)
						board[pos.x][pos.y] = curr_rune
						break
					}
				}
				if found {
					found = false
					break
				}
			}
		}
	}

	return val_found, ok
}

check_for_loners_in_columns :: proc(dbg_log:=false) ->
(val_found:=false, ok:=true) {
	pot_runes : [dynamic]rune
	rune_slice : [BOARD_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int

	for i in 0..<BOARD_SIZE {
		if dbg_log { fmt.println("column:", i) }
		for j in 0..<BOARD_SIZE {
			rune_counter[j] = 0
		}
		for j in 0..<BOARD_SIZE {
			pos := Position{j, i}
			pot_runes, ok = get_possible_values(pos)
			for pot_rune in pot_runes {
				if dbg_log { fmt.print(pot_rune) }
				index := int(pot_rune - '1')
				if dbg_log { fmt.print(index, ' ') }
				rune_counter[index] += 1
			}
			rune_slice[j] = pot_runes
			
		}
		if dbg_log { 
			fmt.println("rune_counter:", rune_counter)
			fmt.println("rune_slice:", rune_slice)
		}

		found := false
		for x in 0..<BOARD_SIZE {
			if rune_counter[x] == 1 {
				curr_rune := rune(x + '1')
				for j in 0..<BOARD_SIZE {
					_, found = slice.linear_search(rune_slice[j][:], curr_rune)
					if found {
						val_found = true
						pos := Position{j, i}
						fmt.println("check_for_loners_in_columns - value for [", pos.x, "][", pos.y, "] determind:", curr_rune)
						board[pos.x][pos.y] = curr_rune
						break
					}
				}
				if found {
					found = false
					break
				}
			}
		}
	}

	return val_found, ok
}

check_for_loners_in_boxes :: proc(dbg_log:=false) ->
(val_found:=false, ok:=true) {
	temp_val_found : bool
	for i in 0..<SQ_SIZE {
		for j in 0..<SQ_SIZE {
			temp_val_found, ok = check_for_loners_in_box(i, j, dbg_log)
			val_found = val_found || temp_val_found
		}
	}
	return val_found, ok
}

check_for_loners_in_box :: proc(x: int, y: int, dbg_log:=false) ->
(val_found:=false, ok:=true) {
	pot_runes : [dynamic]rune
	rune_map : [SQ_SIZE][SQ_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int
	box := Position{x,  y}
	if dbg_log { fmt.println("box:", x, ",", y) }

	for i in 0..<SQ_SIZE {
		for j in 0..<SQ_SIZE {
			pos := Position{(SQ_SIZE * box.x) + i, (SQ_SIZE * box.y) + j}
			pot_runes, ok = get_possible_values(pos)
			for pot_rune in pot_runes {
				//fmt.print(pot_rune)
				index := int(pot_rune - '0')
				//fmt.print(index, ' ')
				rune_counter[index-1] += 1
			}
			rune_map[i][j] = pot_runes
		}
	}

	//fmt.println("rune_counter:", rune_counter)
	//fmt.println("rune_map:", rune_map)
	found := false
	for x in 0..<BOARD_SIZE {
		if rune_counter[x] == 1 {
			curr_rune := rune(x+1 + '0')
			for i in 0..<SQ_SIZE {
				for j in 0..<SQ_SIZE {
					_, found = slice.linear_search(rune_map[i][j][:], curr_rune)
					if found {
						val_found = true
						pos := Position{(SQ_SIZE * box.x) + i, (SQ_SIZE * box.y) + j}
						fmt.println("check_for_loners_in_box - value for [", pos.x, "][", pos.y, "] determind:", curr_rune)
						board[pos.x][pos.y] = curr_rune
						break
					}
				}
				if found {
					found = false
					break
				}
			}
		}
	}
	return val_found, ok
}

get_neighbors_in_box :: proc(x: int, y: int) -> 
(result: [dynamic]rune, ok:=true) {
	neighbors : [dynamic]rune
	box := Position{x/3,  y/3}
    // defer delete(box) not needed, Local variables are allocated on the stack and are deleted upon exit
	//fmt.println("box:", x/3, ",", y/3)

	for i in 0..<SQ_SIZE {
		for j in 0..<SQ_SIZE {
			pos := Position{(SQ_SIZE * box.x) + i, (SQ_SIZE * box.y) + j}
			//fmt.println(board[pos.x][pos.y])
			skip_cell := pos.x == x && pos.y == y
			if !skip_cell && board[pos.x][pos.y] != '.' {
    			append(&neighbors, board[pos.x][pos.y])
			}
		}
	}
	//fmt.println("neighbors in square:", neighbors)
	return neighbors, ok
}

get_neighbors_in_row :: proc(x: int, y: int) -> (result: [dynamic]rune, ok:=true) {
	neighbors : [dynamic]rune

	for i in 0..<BOARD_SIZE {
		if (i != y) && (board[x][i] != '.') {
    		append(&neighbors, board[x][i])
			//fmt.println(board[x][i])
		}
	}
	//fmt.println("neighbors in row:", neighbors)
	return neighbors, ok
}

get_neighbors_in_col :: proc(x: int, y: int) -> (result: [dynamic]rune, ok:=true) {
	neighbors : [dynamic]rune

	for i in 0..<BOARD_SIZE {
		if (i != x) && (board[i][y] != '.') {
    		append(&neighbors, board[i][y])
			//fmt.println(board[i][y])
		}
	}
	//fmt.println("neighbors in column:", neighbors)
	return neighbors, ok
}

get_possible_values :: proc(
	pos: Position,
	dbg_print:=false
) -> (result: [dynamic]rune, ok:=true) {
	possible_vals : [dynamic]rune

	if board[pos.x][pos.y] != '.' {
		//fmt.println("WARNING: already assigned a value!")
		return possible_vals, true
	}

	get_possible_val :: proc(runes: [dynamic]rune) -> (result: [dynamic]rune) {
		for i in 0..<BOARD_SIZE {
			curr_rune := rune(i + '1')
			_, found := slice.linear_search(runes[:], curr_rune)
			if !found {
				append(&result, curr_rune)
				return result
			}
		}
		return result
	}

	row_neighbors, _ := get_neighbors_in_row(pos.x, pos.y)
	//fmt.println("neighbors in row:", row_neighbors)
	if len(row_neighbors) == BOARD_SIZE-1 {
		return get_possible_val(row_neighbors), true
	}

	col_neighbors, _ := get_neighbors_in_col(pos.x, pos.y)
	//fmt.println("neighbors in column:", col_neighbors)
	if len(col_neighbors) == BOARD_SIZE-1 {
		return get_possible_val(col_neighbors), true
	}

	box_neighbors, _ := get_neighbors_in_box(pos.x, pos.y)
	//fmt.println("neighbors in square:", box_neighbors)
	if len(box_neighbors) == BOARD_SIZE-1 {
		return get_possible_val(box_neighbors), true
	}

	for i in 0..<BOARD_SIZE {
		curr_rune := rune(i+1 + '0')
		_, in_row := slice.linear_search(row_neighbors[:], curr_rune)
		_, in_col := slice.linear_search(col_neighbors[:], curr_rune)
		_, in_box := slice.linear_search(box_neighbors[:], curr_rune)
		if !in_row && !in_col && !in_box {
    		append(&possible_vals, curr_rune)
			//fmt.println(curr_rune)
		}
	}
	if len(possible_vals) == 1 || dbg_print {
		fmt.println("position:", pos)
		fmt.println("possible values:", possible_vals)
	}
	return possible_vals, ok
}

clean_up_stragglers :: proc() -> (ok:=true) {
	update_board_pot()
	stragglers_found := false
	for x in 0..<BOARD_SIZE {
		for y in 0..<BOARD_SIZE {
			if board[x][y] == '.' {
				if len(board_pot[x][y]) == 1 {
					fmt.println("position: {", x, ",", y, "} =", board_pot[x][y][0])
					board[x][y] = board_pot[x][y][0]
					stragglers_found = true
				}
			}
		}
	}
	if stragglers_found {
		// do another sweep
		ok = clean_up_stragglers()
	}
	return ok
}

is_complete :: proc() -> (is_complete: bool, ok:=true) {
	pot_runes : [dynamic]rune
	rune_map : [SQ_SIZE][SQ_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int
	//fmt.println("box:", x, ",", y)

	/*
	for i in 0..<BOARD_SIZE-1 {
		for j in 0..<BOARD_SIZE-1 {
			pos := Position{(SQ_SIZE * x) + i/3, (SQ_SIZE * y) + i%%3}
			pot := board_pot[pos.x][pos.y][:]
			//fmt.println("pot:", pot)
		}
	}
	// */
	return is_complete, ok
}

main :: proc() {
	fmt.println("Sudoku start!")
	ok : bool
	board, ok = read_sudoku_csv("sudoku_3.csv")
	update_board_pot(reset=true)
    if !ok { return }

	print_sudoku_board()
	print_sudoku_board_pot()

	//get_possible_values(Position{0, 5}, true)
	ok = clean_up_stragglers()
	if !ok { fmt.print("error") }

	solved := false
	progress_made : bool
	tmp_progress_made : bool
	/*
	x: int = 42
	ptr: ^int = &x  // ptr is a pointer to an integer
	// Dereferencing to read or write value
	val: int = ptr^  // val is now 42
	ptr^ = 100       // x is now 100
	*/
	for {
		//Go through all of our algorithms, trying to fill in cells
		tmp_progress_made, ok = check_for_loners()
		ok = find_hidden_sets_in_rows(&progress_made)
		print_sudoku_board()
		print_sudoku_board_pot()
		
		update_board_pot()
		//clean_up_stragglers()
		
		fmt.println("progress_made:", progress_made)
		fmt.println("tmp_progress_made:", tmp_progress_made)
		if !(tmp_progress_made || progress_made) {
			break
		}
		progress_made = false
		tmp_progress_made = false
	}
	if !solved {
		print_sudoku_board()
		print_sudoku_board_pot()
		fmt.println("Not solved")
	}

	/*

	update_board_pot()
	clean_up_stragglers()
	//find_hidden_pairs_in_rows()
	//find_hidden_pairs_in_cols()
	//find_hidden_pairs_in_boxes()
	//find_hidden_sets_in_cols()
	clean_up_stragglers()
	find_hidden_pairs_in_boxes()
	//find_hidden_sets_in_boxes()
	find_hidden_sets_in_boxes()
	// */
	//find_hidden_sets_in_box(2, 0, true)


	fmt.println()
	fmt.println("Sudoku end!")
}