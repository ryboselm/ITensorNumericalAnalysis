using Test
using ITensorNumericalAnalysis

using NamedGraphs: vertices
using NamedGraphs.NamedGraphGenerators: named_grid, named_comb_tree
using ITensors: siteinds, inds
using Dictionaries: Dictionary
using Random: Random

@testset "indexmap tests" begin
  @testset "test single dimensional index map" begin
    L = 4

    g = named_grid((L, L))

    s = continuous_siteinds(g)

    @test dimension(s) == 1

    x = 0.625
    ind_to_ind_value_map = calculate_ind_values(s, x)
    @test Set(keys(ind_to_ind_value_map)) == Set(inds(s))
    @test only(calculate_p(s, ind_to_ind_value_map)) == x
  end

  @testset "test multi dimensional index map" begin
    L = 10
    g = named_grid((L, L))
    s = continuous_siteinds(g, [[(i, j) for i in 1:L] for j in 1:L])

    x, y = 0.5, 0.75
    ind_to_ind_value_map = calculate_ind_values(s, [x, y], [1, 2])
    xyz = calculate_p(s, ind_to_ind_value_map, [1, 2])
    @test first(xyz) == x
    @test last(xyz) == y

    xyzvals = [rand() for i in 1:L]
    ind_to_ind_value_map = calculate_ind_values(s, xyzvals)

    xyzvals_approx = calculate_p(s, ind_to_ind_value_map, [i for i in 1:dimension(s)])
    xyzvals ≈ xyzvals_approx
  end

  @testset "test grid_points" begin
    L = 16
    base = 2
    g = named_comb_tree((2, L ÷ 2))
    s = continuous_siteinds(g; map_dimension=2)

    #first set -- irregular span
    N = 125
    a = 0.12
    b = 0.95
    test_gridpoints = grid_points(s, N, 1, [a, b])

    points_in_span = floor(b * base^(L / 2)) - ceil(a * base^(L / 2)) + 1
    N_gridpoints = Int(floor(points_in_span / ceil(points_in_span / N))) + 1

    @test length(test_gridpoints) == N_gridpoints
    @test test_gridpoints[1] >= a
    @test test_gridpoints[end] < b
    internal = (test_gridpoints[2] - test_gridpoints[1])
    left = (test_gridpoints[1] - a)
    right = (b - test_gridpoints[end])
    @test internal >= left && internal >= right

    #second set
    N = 32
    a = 0.25
    b = 0.5
    test2 = grid_points(s, N, 1, [a, b])
    @test length(test2) == N
    @test test2[1] >= a
    @test test2[end] < b
    internal = (test2[2] - test2[1])
    left = (test2[1] - a)
    right = (b - test2[end])
    @test internal >= left && internal >= right

    #third set
    test3 = grid_points(s, 1)
    @test length(test3) == 256
    @test test3[1] >= 0
    @test test3[end] < 1
    internal = (test3[2] - test3[1])
    left = (test3[1] - a)
    right = (b - test3[end])
    @test internal >= left && internal >= right

    #test the rand() function to see if it succeeds
    rng = Random.Xoshiro(42)
    rand_gridpoint1 = rand_p(rng, s)
    rand_gridpoint2 = rand_p(rng, s, 1)

    #fourth set -- very large L
    L = 140
    base = 2
    g = named_comb_tree((2, L ÷ 2))
    s = continuous_siteinds(g; map_dimension=2)
    n_grid = 16
    @test length(grid_points(s, n_grid, 1)) == n_grid
  end
end
