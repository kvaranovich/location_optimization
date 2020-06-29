julia p_mp_model_jump.jl --city winnipeg --metric distance --p 9 --m 20 --n 200 --q 1 --r 3000.00 --seed 1
julia mclp_model_jump.jl --city winnipeg --metric distance --p 9 --m 20 --n 200 --q 1 --r 3000.00 --seed 1
julia iterative_model.jl --city winnipeg --metric time --p 9 --r 100.00 --R 600.0 --q 1 --ruin_random 0.5 --initialization_strategy centered --seed 1
julia hierarchical_iterative_model.jl --city winnipeg --metric time --p 9 --r 400.00 --R 600.0 --q 1 --ruin_random 0.5 --initialization_strategy centered --seed 1