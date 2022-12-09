#scenario1.jl
filename = "scenario1"
include("../src/core.jl")

function func1()
end
function func2()
end

function main(a, b, c) 
    ...
end
function main(a)

end

iters = [(a, b, c) for a in ..., b in ..., c in ...][:]  

num_repeat = 500
num_workers = 180
parallel_param = ParallelParam(Tout = Matrix{Int16}, 
    num_repeat = num_repeat, num_workers = num_workers)


parallel(filename, main, iters, parallel_param)

main(iters[i]...)
main(iters[i])

