let concat (type a) (xs, ys : a list * a list) : a list =
    let f (x,ys : (a * a list)) : a list = x :: ys in
    List.fold_right f xs ys

let flat_map (type a b) (f : (a -> b list)) (src : a list) :  b list =
	List.fold_right concat (List.map f src) []

let compact_list (type a) (l : a option list) : a list =
    List.fold_right
    (fun (val, lst : a option * a list ) : a list ->
        match val with
        | None -> lst
        | Some b -> b :: lst
    ) l []

let filter_map (type a b) (f : (a -> b option)) (src : a list) : b list =
    let option_list: b option list = List.map f src in
        compact_list option_list
