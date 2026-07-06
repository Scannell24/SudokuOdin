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

	// 2. Prepare the [][]rune
	records = make([][]rune, len(csv_records))

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

get_possible_values :: proc(pos: Position) -> (result: [dynamic]rune, ok: bool) {
	possible_vals : [dynamic]rune
	//fmt.println("position:", pos)

	if board[pos.x][pos.y] != '.' {
		fmt.println("WARNING: already assigned a value!")
		return possible_vals, true
	}

	row_neighbors, _ := get_neighbors_in_row(pos.x, pos.y)
	//fmt.println("neighbors in row:", row_neighbors)
	if len(row_neighbors) == 1 {
		return row_neighbors, true
	}

	col_neighbors, _ := get_neighbors_in_col(pos.x, pos.y)
	//fmt.println("neighbors in column:", col_neighbors)
	if len(col_neighbors) == 1 {
		return col_neighbors, true
	}

	box_neighbors, _ := get_neighbors_in_box(pos.x, pos.y)
	//fmt.println("neighbors in square:", box_neighbors)
	if len(box_neighbors) == 1 {
		return box_neighbors, true
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
	//fmt.println("possible values:", possible_vals)
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

	clean_up_stragglers()

	print_sudoku_board()

	solved := true
	for !solved {
		fmt.println("Human solve")
	}


	fmt.println()
	fmt.println("Sudoku end!")
}