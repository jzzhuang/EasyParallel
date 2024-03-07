filename = "example_mc"
startfilename = "example_0101.jl"
include("../src/Project.jl")

num_repeat = 40
parallel_param = create_parallel_param(
    Tout = Float64, num_repeat = num_repeat, num_workers = 4, num_threads = 2, ignore_wait = true)

# we recommended num_threads to be set larger than 1 for large-scale matrix manipulation, e.g. Yao.jl

function main(x, y)
    y*monte_carlo(x)
end

if (myid() == 1)
    iters = [(x, y) for x in 1:10 for y in 0.1:0.1:0.5]
    data = parallel(filename, startfilename, main, iters, parallel_param)
end