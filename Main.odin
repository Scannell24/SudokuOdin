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

update_board_pot :: proc() -> (ok: bool) {
	potential_runes : [dynamic]rune
	neighbors : [dynamic]rune
	for x in 0..<BOARD_SIZE {
		for y in 0..<BOARD_SIZE {
			pos := Position{x, y}
			if board[x][y] == '.' {
				potential_runes, ok = get_possible_values(pos)
				board_pot[x][y] = potential_runes
				//for val in potential_runes {
				//	append(&board_pot[x][y], val)
				//}
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

//TODO
//delete_potential_vals_from_cell
del_potential_vals :: proc() -> (ok: bool) {
	ok = true
	return ok
}

//TODO TODO makes it flexible up to N?
//TODO
find_hidden_pairs :: proc() -> (ok: bool) {
	ok = true
	rune_slice : [BOARD_SIZE][dynamic]rune
    append(&rune_slice[0], '1')
    append(&rune_slice[0], '2')
    append(&rune_slice[1], '1')
    append(&rune_slice[1], '2')
	fmt.println("rune_slice:", rune_slice)
	fmt.println("rune_slice[0]:", rune_slice[0])
	are_equal := slice.equal(rune_slice[0][:], rune_slice[1][:])
	fmt.println("rune_slice equal?:", are_equal)
	//for i in 0..<BOARD_SIZE {
	//}

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
			curr_rune := rune(i+1 + '0')
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
	possible_vals : [dynamic]rune
	ok := true
	stragglers_found := false
	for i in 0..<BOARD_SIZE {
		for j in 0..<BOARD_SIZE {
			position := Position{i, j}
			if board[i][j] == '.' {
				possible_vals, _ = get_possible_values(position)
				if len(possible_vals) == 1 {
					fmt.println("position:", position, "=", possible_vals[0])
					fmt.println("possible_vals:", possible_vals)
					board[i][j] = possible_vals[0]
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

main :: proc() {
	fmt.println("Sudoku start!")

	new_board, ok := read_sudoku_csv("sudoku_1.csv")
	board = new_board
    if !ok { return }

	print_sudoku_board()

	//get_possible_values(Position{0, 5}, true)
	ok = clean_up_stragglers()
	if !ok {
		fmt.print("error")
	}

	print_sudoku_board()

	solved := true
	for !solved {
		fmt.println("Human solve")
	}

	check_for_loners_in_boxes()
	print_sudoku_board()
	clean_up_stragglers()
	check_for_loners_in_columns()
	check_for_loners_in_rows()

	update_board_pot()
	print_sudoku_board_pot()
	print_sudoku_board()

	find_hidden_pairs()


	fmt.println()
	fmt.println("Sudoku end!")
}