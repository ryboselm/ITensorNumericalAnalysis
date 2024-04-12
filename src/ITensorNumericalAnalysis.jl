module ITensorNumericalAnalysis

include("bitmap.jl")
include("utils.jl")
include("polynomialutils.jl")
include("itensornetworkfunction.jl")
include("elementary_functions.jl")
include("elementary_operators.jl")

export ITensorNetworkFunction, itensornetwork
export BitMap,
  default_dimension_map,
  vertex,
  calculate_xyz,
  calculate_x,
  calculate_bit_values,
  dimension,
  base,
  grid_points
export const_itensornetwork,
  exp_itensornetwork,
  cosh_itensornetwork,
  sinh_itensornetwork,
  tanh_itensornetwork,
  cos_itensornetwork,
  sin_itensornetwork,
  get_edge_toward_root,
  polynomial_itensornetwork,
  random_itensornetworkfunction,
  laplacian_operator,
  first_derivative_operator,
  second_derivative_operator,
  third_derivative_operator,
  fourth_derivative_operator,
  identity_operator
export const_itn,
  poly_itn, cosh_itn, sinh_itn, tanh_itn, exp_itn, sin_itn, cos_itn, rand_itn
export calculate_fx, calculate_fxyz
export operate, operator, multiply

end
