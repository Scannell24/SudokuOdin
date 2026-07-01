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

    // Create a string builder to collect the table output
    sb := strings.builder_make()
    defer strings.builder_destroy(&sb)

    // Initialize the table structure
    tbl: table.Table
    table.init(&tbl)
    defer table.destroy(&tbl)

    // Add table decorations and headers
    table.caption(&tbl, "Board")
    
    // Add data rows
	// TODO: not quite right!
    for row in board {
    	table.row(&tbl, row)
	}

    // Write the plain structured table to our builder
    writer := strings.to_writer(&sb)
    table.write_plain_table(writer, &tbl)

    // Convert to a string and print to console
    table_string := strings.to_string(sb)
    fmt.println(table_string)
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