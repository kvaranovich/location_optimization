julia p_mp_model_jump.jl --city winnipeg --metric distance --p 9 --m 20 --n 200 --q 1
julia mclp_model_jump.jl --city winnipeg --metric distance --p 9 --m 20 --n 200 --q 1 --r 3000.00
julia iterative_model.jl --city winnipeg --metric time --p 9 --r 100.00