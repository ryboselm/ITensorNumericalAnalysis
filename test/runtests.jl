using Test
using Glob
using ITensorNetworks
using QTTITensorNetworks

# https://discourse.julialang.org/t/rdir-search-recursive-for-files-with-a-given-name-pattern/75605/12
@testset "test directory $root" for (root, dirs, files) in
                                    walkdir(joinpath(pkgdir(QTTITensorNetworks), "test"))
  test_files = filter!(f -> occursin(Glob.FilenameMatch("test_*.jl"), f), files)
  @testset "Test file $test_file" for test_file in test_files
    println("Running test file $test_file")
    @time include(joinpath(root, test_file))
  end
end

nothing