let concat (type a) (xs, ys : a list * a list) : a list =
    let f (x,ys : (a * a list)) : a list = x :: ys in
    List.fold_right f xs ys

let flat_map (type a b) (f : (a -> b list)) (src : a list) :  b list =
	List.fold_right concat (List.map f src) []
