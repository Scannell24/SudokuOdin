package main

import "core:encoding/csv"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:text/table"
import "core:unicode/utf8"

SQUARE_SIZE : int : 3
BOARD_SIZE : int : SQUARE_SIZE * SQUARE_SIZE

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

print_sudoku_board :: proc(board: [][]rune) {
	fmt.println()
	fmt.println("+ - - - + - - - + - - - +")
	for w in 0..<SQUARE_SIZE {
		for x in 0..<SQUARE_SIZE {
			for y in 0..<SQUARE_SIZE {
				fmt.print('|')
				for z in 0..<SQUARE_SIZE {
					fmt.print("", board[w*SQUARE_SIZE+x][y*SQUARE_SIZE+z])
				}
				fmt.print(" ")
			}
			fmt.println('|')
		}
		fmt.println("+ - - - + - - - + - - - +")
	}
	fmt.println()
}

get_neighbors_in_square :: proc(board: [][]rune, x: int, y: int) -> (result: [dynamic]rune, ok: bool) {
	neighbors : [dynamic]rune
	return neighbors, true
}

get_neighbors_in_row :: proc(board: [][]rune, x: int, y: int) -> (result: [dynamic]rune, ok: bool) {
	neighbors : [dynamic]rune

	for i in 0..<BOARD_SIZE {
		if (i != y) && (board[x][i] != '.') {
    		append(&neighbors, board[x][i])
			//fmt.println(board[x][i])
		}
	}
	return neighbors, true
}

get_neighbors_in_col :: proc(board: [][]rune, x: int, y: int) -> (result: [dynamic]rune, ok: bool) {
	neighbors : [dynamic]rune

	for i in 0..<BOARD_SIZE {
		if (i != x) && (board[i][y] != '.') {
    		append(&neighbors, board[i][y])
			//fmt.println(board[i][y])
		}
	}
	return neighbors, true
}

main :: proc() {
	fmt.println("Sudoku start!")

	records, ok := read_sudoku_csv("easy_01.csv")
    if !ok { return }

    // Remember to free the records array and its strings
    defer {
        for record in records {
            delete(record)
        }
        delete(records)
    }

	print_sudoku_board(records)

	position := Position{0, 0}
	row_neighbors, _ := get_neighbors_in_row(records, position.x, position.y)
	fmt.println("neighbors in row:", row_neighbors)

	col_neighbors, _ := get_neighbors_in_col(records, position.x, position.y)
	fmt.println("neighbors in column:", col_neighbors)

	//sq_neighbors, _ := get_neighbors_in_square(records, position.x, position.y)
	//fmt.println("neighbors in square:", sq_neighbors)

	solved := true
	for !solved {
		fmt.println("Human solve")
	}


	fmt.println()
	fmt.println("Sudoku end!")
}