using ApproxFun:
  Interval, Fourier, Chebyshev, Fun, ProductFun, coefficients, chop, ncoefficients
using Interpolations: LinearInterpolation, Line

""" Helper function for fourier_itensornetwork and fourier_2D_itensornetwork """
function fourier_term(s::IndsNetworkMap, j::Integer, d::Integer)
  if j == 1
    return const_itn(s)
  elseif j % 2 == 0
    return sin_itn(s; k=j * π, dim=d)
  else
    return cos_itn(s; k=(j - 1) * π, dim=d)
  end
end

""" Build the function f(x) = coeffs[1] + ∑_{k=1}^{n} coeffs[2k]*sin(2kπx) 
    + ∑_{k=1}^{n} coeffs[2k+1]*cos(2kπx)  """
function fourier_itensornetwork(
  s::IndsNetworkMap,
  coeffs::Vector{<:Union{AbstractFloat, Complex{<:AbstractFloat}}};
  dim::Int=1,
  min_threshold=1e-15,
  cutoff=1e-16
)
  n = length(coeffs)
  if n < 1
    throw("coeffs must be nonempty")
  end

  ψ = coeffs[1] * const_itn(s)
  for i in 2:n
    if abs(coeffs[i]) > min_threshold
      ψ += coeffs[i] * fourier_term(s, i, dim)
      ψ = truncate(ψ; cutoff)
    end
  end
  return ψ
end

""" Build the function f(x,y) = ∑_{j=1}^n ∑_{k=1}^n coeffs[j, k]*ϕ_j(x)*ϕ_k(y) where ϕ_j and ϕ_k are sines/cosines. """
function fourier_2D_itensornetwork(
  s::IndsNetworkMap, coeffs::Matrix{<:Union{AbstractFloat, Complex{<:AbstractFloat}}}; dims::Vector{Int}=[1, 2], min_threshold=1e-15, cutoff=1e-16
)
  n = size(coeffs)[1]
  m = size(coeffs)[2]
  if n < 1 || m < 1
    throw("coeffs must be nonempty")
  end

  ψ = const_itn(s; c=0)
  for j in 1:n
    for k in 1:m
      if abs(coeffs[j, k]) > min_threshold
        ψ += coeffs[j, k] * fourier_term(s, j, dims[1]) * fourier_term(s, k, dims[2])
        ψ = truncate(ψ; cutoff)
      end
    end
  end
  return ψ
end

""" Build the function f(x) = ∑_{k=1}^n coeffs[k] * T_k(x) 
    where T_k(x) is the k-th Chebyshev polynomial. """
function chebyshev_itensornetwork(
  s::IndsNetworkMap, coeffs::Vector{<:Union{AbstractFloat, Complex{<:AbstractFloat}}}; dim::Int=1, cutoff=1e-16
)
  n = length(coeffs)
  if n <= 0
    throw("coeffs must be nonempty")
  elseif n == 1
    return coeffs[1] * const_itn(s)
  end

  #Clenshaw Evaluation method - uses idea from https://arxiv.org/pdf/2407.09609
  y_n = const_itn(s; c = 0)
  y_n1 = const_itn(s; c = 0)

  # y_n-1 = c_n-1 - y_n+1 + (4x-2) * y_n
  for d in n:-1:1
    old_y_n = truncate(y_n; cutoff)
    y_n = coeffs[d] * const_itn(s) + (-1) * y_n1 + poly_itn(s, [-2, 4]; dim) * old_y_n
    y_n1 = old_y_n
  end

  return truncate(y_n + poly_itn(s, [1,-2]; dim) * y_n1; cutoff)
end

""" Build the function f(x,y) = ∑_{j=1}^n ∑_{k=1}^n coeffs[j, k]*ϕ_j(x)*ϕ_k(y) where ϕ_j and ϕ_k are chebyshev polynomials """
function chebyshev_2D_itensornetwork(
  s::IndsNetworkMap, coeffs::Matrix{<:Union{AbstractFloat, Complex{<:AbstractFloat}}}; dims::Vector{Int}=[1, 2], cutoff=1e-16
)
  n = size(coeffs)[1]
  m = size(coeffs)[2]
  if n < 1 || m < 1
    throw("coeffs must be nonempty")
  end
  
  #Clenshaw Evaluation method - uses idea from https://arxiv.org/pdf/2407.09609
  y_n = const_itn(s; c = 0)
  y_n1 = const_itn(s; c = 0)

  for j in m:-1:1
    #determine the weighted sum of chebyshev polynomials of x
    x_n = const_itn(s; c = 0)
    x_n1 = const_itn(s; c = 0)
    for i in n:-1:1
       # x_n-1 = c_n-1 - x_n+1 + (4x-2) * x_n
      old_x_n = truncate(x_n; cutoff)
      x_n = coeffs[i,j] * const_itn(s) + (-1) * x_n1 + poly_itn(s, [-2, 4]; dim=dims[1]) * old_x_n
      x_n1 = old_x_n
    end
    coeff_j =  truncate(x_n + poly_itn(s, [1,-2]; dim=dims[1]) * x_n1; cutoff)

    # y_n-1 = c_n-1 - y_n+1 + (4y-2) * y_n
    old_y_n = truncate(y_n; cutoff)
    y_n = coeff_j + (-1)*y_n1 + poly_itn(s, [-2, 4]; dim=dims[2]) * old_y_n
    y_n1 = old_y_n
  end

  return truncate(y_n + poly_itn(s, [1,-2]; dim=dims[2]) * y_n1; cutoff)
end

""" Helper function for function_itensornetwork (1D case) """
function greatest_n(coeffs, n)
  if n < 1
    throw("n must be greater than 0")
  end
  sorted_indices = sortperm(coeffs; by=abs, rev=true)
  top_n_indices = sorted_indices[1:min(n, length(coeffs))]
  output = zeros(eltype(coeffs), length(coeffs))
  output[top_n_indices] = coeffs[top_n_indices]
  last_non_zero = findlast(output .!= 0)
  if isempty(last_non_zero)
    return []
  end
  return output[1:last_non_zero]
end

""" Helper function for function_itensornetwork (2D case) """
function greatest_n_2d(coeffs_matrix, n)
  if n < 1
    throw("n must be greater than 0")
  end
  dims = size(coeffs_matrix)
  coeffs = vec(coeffs_matrix)
  sorted_indices = sortperm(coeffs; by=abs, rev=true)
  top_n_indices = sorted_indices[1:min(n, length(coeffs))]
  output = zeros(eltype(coeffs), length(coeffs))
  output[top_n_indices] = coeffs[top_n_indices]
  matrix = reshape(output, dims)
  last_row, last_col = size(matrix)
  while last_row > 0 && all(matrix[last_row, :] .== 0)
    last_row -= 1
  end
  while last_col > 0 && all(matrix[:, last_col] .== 0)
    last_col -= 1
  end
  return matrix[1:last_row, 1:last_col]
end

""" 
    function_itensornetwork(s,f, cutoff=1e-3, max_coeffs=100, mode="fourier", by_mag=true)
    Takes in a function `f` as a black box, outputs a tensor network approximation using Fourier or Chebyshev series. Supports 1D or 2D functions.

    #Arguments
    - `s`: IndsNetworkMap
    - `f`: a real-valued function on domain [0,1] or [0,1]⊗[0,1] which can be given as a black box
    - `cutoff`: (default=1e-3) specifies at what value should the fourier/chebyshev coefficients be truncated below
    - `max_coeffs`: the maximum number of coefficients allowed in 1D. In 2D, it is the maximum degree of a coefficient in each dimension
    - `mode`: ["fourier", "chebyshev"] "fourier" uses a fourier basis and "chebyshev" uses a chebyshev polynomial basis
    - `by_mag`: boolean. if false, will use the `max_coeffs` coefficients of lowest degree. if true, will use the `max_coeffs` coefficients of greatest absolute magnitude.
    - `trunc_level`: what cutoff the periodic truncation is done at
"""
function function_itensornetwork(
  s::IndsNetworkMap,
  f::Function;
  cutoff::Float64=1e-3,
  max_coeffs::Integer=100,
  mode="fourier",
  by_mag=false,
  trunc_level=1e-16
)

  #get the number of inputs to f
  method_list = methods(f).ms
  arg_counts = [length(m.sig.parameters) - 1 for m in method_list]
  num_inputs = arg_counts[1]

  """ 1D functions """
  if num_inputs == 1
    if mode == "fourier"
      S = Fourier(Interval(0.0, 1.0))
      f_fourier = Fun(f, S)
      a = chop(f_fourier, cutoff)
      if by_mag
        cf = greatest_n(coefficients(a), max_coeffs)
      else
        cf = ncoefficients(a) > max_coeffs ? coefficients(a)[1:max_coeffs] : coefficients(a)
      end
      ψ = fourier_itensornetwork(s, cf; cutoff=trunc_level)
    elseif mode == "chebyshev"
      T = Chebyshev(Interval(0.0, 1.0))
      f_chebyshev = Fun(f, T)
      a = chop(f_chebyshev, cutoff)
      if by_mag
        cf = greatest_n(coefficients(a), max_coeffs)
      else
        cf = ncoefficients(a) > max_coeffs ? coefficients(a)[1:max_coeffs] : coefficients(a)
      end
      ψ = chebyshev_itensornetwork(s, cf; cutoff=trunc_level)
    else
      throw("mode $mode not recognized")
    end
    return ψ

    """ 2D functions """
  elseif num_inputs == 2
    if mode == "fourier"
      S = Fourier(Interval(0.0, 1.0))^2
      f_fourier = ProductFun(f, S; tol=cutoff)
      if by_mag
        cf = greatest_n_2d(coefficients(f_fourier), max_coeffs)
      else
        a = min(max_coeffs, size(coefficients(f_fourier))[1])
        b = min(max_coeffs, size(coefficients(f_fourier))[2])
        cf = coefficients(f_fourier)[1:a, 1:b]
      end
      ψ = fourier_2D_itensornetwork(s, cf; dims=[1, 2], cutoff=trunc_level)
    elseif mode == "chebyshev"
      T = Chebyshev(Interval(0.0, 1.0))^2
      f_chebyshev = ProductFun(f, T; tol=cutoff)
      if by_mag
        cf = greatest_n_2d(coefficients(f_chebyshev), max_coeffs)
      else
        a = min(max_coeffs, size(coefficients(f_chebyshev))[1])
        b = min(max_coeffs, size(coefficients(f_chebyshev))[2])
        cf = coefficients(f_chebyshev)[1:a, 1:b]
      end
      ψ = chebyshev_2D_itensornetwork(s, cf; dims=[1, 2], cutoff=trunc_level)
    else
      throw("mode $mode not recognized")
    end
    return ψ
  else
    throw("functions with $num_inputs inputs not supported.")
  end
end

""" 
    data_itensornetwork converts a list of numerical datapoints into an ITN by first converting it into a function. Can be 1D or 2D data.
  
    #Arguments
    - `s`: IndsNetworkMap
    - `data`: a real-valued vector or matrix of data points
    - `eval_pts`: optional, where the data is located. by default it will the data as evenly spaced over [0,1] or [0,1]⊗[0,1], depending on dimension of the data.
    - other kwargs are inherited from `function_itensornetwork`

"""
function data_itensornetwork(s::IndsNetworkMap, data, eval_pts=nothing; kwargs...)
  dimensionality = length(size(data))

  if dimensionality == 1
    #if no eval_pts are given, assumes that the data is evenly spaced across [0,1]
    if eval_pts == nothing
      eval_pts = grid_points(s, length(data), 1; exact_grid=false)
    end
    if length(eval_pts) != length(data)
      throw("length of data and eval_pts do not match!")
    end
    f = LinearInterpolation(eval_pts, data; extrapolation_bc=Line())
    g = (x) -> f(x) #make a function g that is defined as f
    return function_itensornetwork(s, g; kwargs...)
  elseif dimensionality == 2
    if eval_pts == nothing
      eval_pts_x = grid_points(s, size(data)[1], 1; exact_grid=false)
      eval_pts_y = grid_points(s, size(data)[2], 2; exact_grid=false)
      eval_pts = (eval_pts_x, eval_pts_y)
    end
    if length(eval_pts[1]) * length(eval_pts[2]) != length(data)
      throw("length of data and eval_pts do not match!")
    end
    f = LinearInterpolation(eval_pts, data; extrapolation_bc=Line())
    g = (x, y) -> f(x, y) #make a function g that is defined identically to f
    return function_itensornetwork(s, g; kwargs...)
  end
end

const fourier_itn = fourier_itensornetwork
const chebyshev_itn = chebyshev_itensornetwork
const function_itn = function_itensornetwork
const data_itn = data_itensornetwork