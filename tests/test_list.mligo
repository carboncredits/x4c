#include "../lib/list.mligo"

let test_concat_both_empty =
	assert (concat (([] : int list), ([] : int list)) = ([] : int list))

let test_concat_left_empty =
	assert (concat (([] : int list), ([1; 2;] : int list)) = ([1; 2;] : int list))

let test_concat_right_empty =
	assert (concat (([1; 2;] : int list), ([] : int list)) = ([1; 2;] : int list))

let test_concat_neither_empty =
	assert (concat (([1; 2;] : int list), ([3; 4;] : int list)) = ([1; 2; 3; 4;] : int list))

type testitem = {
	items : nat list;
}

let test_flat_map_simple =
	let input: testitem list = [ { items = [1n; 2n;]}; { items = [3n; 4n]}] in
	let res: nat list = flat_map
		(fun (y : testitem): nat list -> y.items )
		input in
	assert (res = [1n; 2n; 3n; 4n;])

let test_flat_map_layer_two =
	let input: testitem list = [ { items = [1n; 2n;]}; { items = [3n; 4n]}] in
	let res: nat list = flat_map
		(fun (y : testitem): nat list ->
			List.map (fun (x: nat): nat -> x + 1n) y.items
		)
		input in
	assert (res = [2n; 3n; 4n; 5n;])

let test_compact_list_simple =
	let input: nat option list = [Some 1n; None; Some 3n; ] in
	let res = compact_list input in
	assert (res = [1n; 3n;])

let test_compact_list_empty =
	let input: nat option list = [] in
	let res = compact_list input in
	assert (res = [])

let test_comapct_list_all_none =
	let input: nat option list = [None; None;] in
	let res = compact_list input in
	assert (res = [])

let test_filter_map_simple =
	let input: int list = [1; 2; 3; 4;] in
	let res = filter_map
		(fun (a: int) : int option ->
			if a = 3 then None else Some a
		) input
	in
	assert (res = [1; 2; 4;])

let test_filter_map_empty =
	let input: int list = [] in
	let res = filter_map
		(fun (a: int) : int option ->
			if a = 3 then None else Some a
		) input
	in
	assert (res = [])
