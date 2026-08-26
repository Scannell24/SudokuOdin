package main

import "core:encoding/csv"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:text/table"
import "core:unicode/utf8"

SQ_SIZE : int : 3
BOARD_SIZE : int : SQ_SIZE * SQ_SIZE
board: [][]rune
board_pot: [][][dynamic]rune // potential values for board cells

Position :: struct {
    x: int,
    y: int,
}

read_sudoku_csv :: proc(csv_path : string) -> (result: [][]rune, ok: bool) {
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
	
	return records, true
}

update_board_pot :: proc(reset:=false) -> (ok: bool) {
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
	fmt.println("+ - - - + - - - + - - - +")
	for w in 0..<SQ_SIZE {
		for x in 0..<SQ_SIZE {
			for y in 0..<SQ_SIZE {
				fmt.print('|')
				for z in 0..<SQ_SIZE {
					fmt.print("", board[w*SQ_SIZE+x][y*SQ_SIZE+z])
				}
				fmt.print(" ")
			}
			fmt.println('|')
		}
		fmt.println("+ - - - + - - - + - - - +")
	}
	fmt.println()
}

//delete_potential_vals_from_cell
del_potential_vals :: proc(row: int, col: int, rune_slice: [dynamic]rune) -> (ok: bool) {
	ok = true
	//fmt.println("rune_slice", rune_slice)
	new_rune_slice: [dynamic]rune
	for pot_rune in board_pot[row][col] {
		_, found := slice.linear_search(rune_slice[:], pot_rune)
		if !found {
			append(&new_rune_slice, pot_rune)
		}
	}
	board_pot[row][col] = new_rune_slice
	if len(new_rune_slice) == 1 {
		board[row][col] = new_rune_slice[0]
		pop(&board_pot[row][col])
	}
	return ok
}

//TODO TODO makes it flexible up to N?
find_hidden_pairs_in_boxes :: proc() -> (ok: bool) {
	ok = true
	for i in 0..<SQ_SIZE {
		for j in 0..<SQ_SIZE {
			ok = find_hidden_pairs_in_box(i, j)
		}
	}
	return ok
}

find_hidden_pairs_in_box :: proc(x: int, y: int) -> (ok: bool) {
	pot_runes : [dynamic]rune
	rune_map : [SQ_SIZE][SQ_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int
	rune_pair : [2]rune
	rune_indices : [2]int
	//fmt.println("box:", x, ",", y)


	for i in 0..<BOARD_SIZE-1 {
		pos := Position{(SQ_SIZE * x) + i/3, (SQ_SIZE * y) + i%%3}
		pot := board_pot[pos.x][pos.y][:]
		//fmt.println("pot:", pot)
	}

	//*
	for i in 0..<BOARD_SIZE {
		pos1 := Position{(SQ_SIZE * x) + i/3, (SQ_SIZE * y) + i%%3}
		pot1 := board_pot[pos1.x][pos1.y][:]
		//fmt.println("pos1:", pos1)
		for j in i+1..<BOARD_SIZE {
			pos2 := Position{(SQ_SIZE * x) + j/3, (SQ_SIZE * y) + j%%3}
			//fmt.println("pos2:", pos2)
			are_equal := slice.equal(pot1, board_pot[pos2.x][pos2.y][:])
			if are_equal && len(pot1) == 2 {
				fmt.println("pair found! ", pos1, " , ", pos2, ": values", pot1)
				//fmt.println("pair found!")
				//fmt.println(pos1, ": ", board_pot[pos1.x][pos1.y][:])
				//fmt.println(pos2, ": ", board_pot[pos2.x][pos2.y][:])
				for z in 0..<BOARD_SIZE {
					//fmt.println("z:", z)
					if i != z && j != z {
						pos := Position{(SQ_SIZE * x) + z/3, (SQ_SIZE * y) + z%%3}
						//fmt.println(pos)
						del_potential_vals(pos.x, pos.y, board_pot[pos1.x][pos1.y])
					}
				}

			}
		}
		//fmt.println()
	}
	// */
	found := false
	return true
}

//TODO TODO makes it flexible up to N?
find_hidden_pairs_in_rows :: proc() -> (ok: bool) {
	ok = true
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

//TODO TODO makes it flexible up to N?
find_hidden_pairs_in_cols :: proc() -> (ok: bool) {
	ok = true
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

is_subset :: proc(slice1: [dynamic]rune, slice2: [dynamic]rune) -> (is_subset: bool, ok: bool) {
	ok = true
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

find_hidden_sets_in_cols :: proc(dbg_log:=false) -> (val_found: bool, ok: bool) {
	ok = true
	val_found = false

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
						val_found = true
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
	return val_found, ok
}

find_hidden_sets_in_rows :: proc() -> (ok: bool) {
	ok = true
	rune_slice : [BOARD_SIZE][dynamic]rune
	rune_set : [2]rune

	/*
	for set_size in 2->5
		for row/col/box in boardsize
			for cell in row/col/box
				if cell's num pot runes == set_size
					curr_cell_coordiante := index
					curr_cell_pot_vals := list
					set := list
					for neighbor_cell in row/col/box
						if neighbor_cell != curr_cell_coordiante:
							is_subset_or_equal = neighbor_cell.pot_vals subset of curr_cell_pot_vals
							if is_subset_or_equal:
								set.append(neighbor_cell)
					if len(set) == set_size
						for neighbor_cell in row/col/box
							if neighbor_cell not in set
								del_potential_vals curr_cell_pot_vals
	*/
	for set_size in 3..<5 {
		//fmt.println("set_size: ", set_size)
		for row_x in 0..<BOARD_SIZE {
			for col_y1 in 0..<BOARD_SIZE {
				if len(board_pot[row_x][col_y1]) == set_size {
					temp_set : [dynamic][dynamic]rune
					temp_indices : [dynamic]int
					append(&temp_set, board_pot[row_x][col_y1])
					append(&temp_indices, col_y1)
					//fmt.println("temp_set:", temp_set)
					for col_y2 in 0..<BOARD_SIZE {
						if col_y1 != col_y2 && len(board_pot[row_x][col_y2]) > 0 {
							is_subset, ok := is_subset(board_pot[row_x][col_y2], board_pot[row_x][col_y1])
							if is_subset {
								append(&temp_set, board_pot[row_x][col_y2])
								append(&temp_indices, col_y2)
								//fmt.println("subset:", board_pot[row_x][col_y2])
							}
						}
					}
					if len(temp_indices) >= set_size {
						fmt.println("temp_set:", temp_set)
						fmt.println("temp_indices:", temp_indices)
						for col_y3 in 0..<BOARD_SIZE {
							_, found := slice.linear_search(temp_indices[:], col_y3)
							if !found && len(board_pot[row_x][col_y3]) > 1 {
								del_potential_vals(row_x, col_y3, temp_set[0])
							}
						}
					}
				}
			}
		}
		// */
	}
	return ok
}

//TODO refine
check_for_loners_in_rows :: proc() -> (ok: bool) {
	ok = true
	pot_runes : [dynamic]rune
	rune_slice : [BOARD_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int

	for i in 0..<BOARD_SIZE {
		//fmt.println("row:", i)
		for j in 0..<BOARD_SIZE {
			rune_counter[j] = 0
		}
		for j in 0..<BOARD_SIZE {
			pos := Position{i, j}
			pot_runes, ok = get_possible_values(pos)
			for pot_rune in pot_runes {
				//fmt.print(pot_rune)
				index := int(pot_rune - '0')
				//fmt.print(index, ' ')
				rune_counter[index-1] += 1
			}
			rune_slice[j] = pot_runes
			
		}
		//fmt.println("rune_counter:", rune_counter)
		//fmt.println("rune_slice:", rune_slice)

		found := false
		for x in 0..<BOARD_SIZE {
			if rune_counter[x] == 1 {
				curr_rune := rune(x+1 + '0')
				for j in 0..<BOARD_SIZE {
					_, found = slice.linear_search(rune_slice[j][:], curr_rune)
					if found {
						pos := Position{i, j}
						fmt.println("value for [", pos.x, "][", pos.y, "] determind:", curr_rune)
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

	return ok
}

//TODO refine
check_for_loners_in_columns :: proc() -> (ok: bool) {
	ok = true
	pot_runes : [dynamic]rune
	rune_slice : [BOARD_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int

	for i in 0..<BOARD_SIZE {
		//fmt.println("column:", i)
		for j in 0..<BOARD_SIZE {
			rune_counter[j] = 0
		}
		for j in 0..<BOARD_SIZE {
			pos := Position{j, i}
			pot_runes, ok = get_possible_values(pos)
			for pot_rune in pot_runes {
				//fmt.print(pot_rune)
				index := int(pot_rune - '1')
				//fmt.print(index, ' ')
				rune_counter[index] += 1
			}
			rune_slice[j] = pot_runes
			
		}
		//fmt.println("rune_counter:", rune_counter)
		//fmt.println("rune_slice:", rune_slice)

		found := false
		for x in 0..<BOARD_SIZE {
			if rune_counter[x] == 1 {
				curr_rune := rune(x + '1')
				for j in 0..<BOARD_SIZE {
					_, found = slice.linear_search(rune_slice[j][:], curr_rune)
					if found {
						pos := Position{j, i}
						fmt.println("value for [", pos.x, "][", pos.y, "] determind:", curr_rune)
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

	return ok
}

check_for_loners_in_boxes :: proc() -> (ok: bool) {
	ok = true
	for i in 0..<SQ_SIZE {
		for j in 0..<SQ_SIZE {
			ok = check_for_loners_in_box(i, j)
		}
	}
	return ok
}

check_for_loners_in_box :: proc(x: int, y: int) -> (ok: bool) {
	pot_runes : [dynamic]rune
	rune_map : [SQ_SIZE][SQ_SIZE][dynamic]rune
	rune_counter : [BOARD_SIZE]int
	box := Position{x,  y}
	//fmt.println("box:", x, ",", y)

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
						pos := Position{(SQ_SIZE * box.x) + i, (SQ_SIZE * box.y) + j}
						fmt.println("value for [", pos.x, "][", pos.y, "] determind:", curr_rune)
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
	return true
}

get_neighbors_in_box :: proc(x: int, y: int) -> (result: [dynamic]rune, ok: bool) {
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
	return neighbors, true
}

get_neighbors_in_row :: proc(x: int, y: int) -> (result: [dynamic]rune, ok: bool) {
	neighbors : [dynamic]rune

	for i in 0..<BOARD_SIZE {
		if (i != y) && (board[x][i] != '.') {
    		append(&neighbors, board[x][i])
			//fmt.println(board[x][i])
		}
	}
	//fmt.println("neighbors in row:", neighbors)
	return neighbors, true
}

get_neighbors_in_col :: proc(x: int, y: int) -> (result: [dynamic]rune, ok: bool) {
	neighbors : [dynamic]rune

	for i in 0..<BOARD_SIZE {
		if (i != x) && (board[i][y] != '.') {
    		append(&neighbors, board[i][y])
			//fmt.println(board[i][y])
		}
	}
	//fmt.println("neighbors in column:", neighbors)
	return neighbors, true
}

get_possible_values :: proc(pos: Position, dbg_print:=false) -> (result: [dynamic]rune, ok: bool) {
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
	return possible_vals, true
}

clean_up_stragglers :: proc() -> (bool) {
	ok := true
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


is_complete :: proc() -> (is_complete: bool, ok: bool) {
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

	print_sudoku_board_pot()
	print_sudoku_board()

	//get_possible_values(Position{0, 5}, true)
	ok = clean_up_stragglers()
	if !ok {
		fmt.print("error")
	}


	solved := true
	for !solved {
		fmt.println("Not solved")
	}

	check_for_loners_in_boxes()
	check_for_loners_in_columns()
	check_for_loners_in_rows()

	update_board_pot()
	clean_up_stragglers()
	//find_hidden_pairs_in_rows()
	//find_hidden_pairs_in_cols()
	//find_hidden_pairs_in_boxes()
	//find_hidden_sets_in_cols()
	find_hidden_sets_in_rows()
	//*
	print_sudoku_board()
	print_sudoku_board_pot()
	// */


	fmt.println()
	fmt.println("Sudoku end!")
}