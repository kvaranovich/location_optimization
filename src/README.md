# src - Source code

- auxillary_functions.jl - different auxillary and helper functions
- distance_matrix.jl - functions for calculating distance matrices and filtering out disconnected nodes
- iterative_model.jl - our iterative location optimization model
- mclp_model_jump.jl - MCLP location model implemented in JuMP
- p_mp_model_jump.jl - p-MP location model implemented in JuMP
- performance_metrics.jl - performance metrics for final layout evaluation
- movement_search_space.jl - functions for different movement search space
- optimization_step.jl - functions defining single iteration of optimization
- optimization.jl - functions for optimization until finding local minimum

## Draft scripts
- plots.jl
- workflow.jl
- draft.jl
- optimization_animation.R - embedded into another script, could be deleted