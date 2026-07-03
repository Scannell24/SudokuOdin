package main

import "core:encoding/csv"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:text/table"

WIDTH : int : 3

read_sudoku_csv :: proc(csv_path : string) -> (result: [][]string, ok: bool) {
    data, err := os.read_entire_file(csv_path, context.allocator)
	records : [][]string
    if err != nil { return records, false}
    defer delete(data, context.allocator)

    // Parse CSV data
    r: csv.Reader
    r.trim_leading_space = true
    defer csv.reader_destroy(&r)
    csv.reader_init_with_string(&r, string(data))

    records, _ = csv.read_all(&r)
	
	return records, true
}

print_sudoku_board :: proc(board: [][]string) {
	fmt.println()
	fmt.println("+ - - - + - - - + - - - +")
	for w in 0..<WIDTH {
		for x in 0..<WIDTH {
			for y in 0..<WIDTH {
				fmt.print('|')
				for z in 0..<WIDTH {
					val := "."
					if board[w*WIDTH+x][y*WIDTH+z] != "" {
						val = board[w*WIDTH+x][y*WIDTH+z]
					}
					fmt.print("", val)
				}
				fmt.print(" ")
			}
			fmt.println('|')
		}
		fmt.println("+ - - - + - - - + - - - +")
	}
	fmt.println()
}

main :: proc() {
	fmt.println("Sudoku start!")

	records, ok := read_sudoku_csv("easy_01.csv")
    if !ok { return }

    // Remember to free the records array and its strings
    defer {
        for record in records {
            for field in record { delete(field) }
            delete(record)
        }
        delete(records)
    }

	print_sudoku_board(records)


	fmt.println()
	fmt.println("Sudoku end!")
}