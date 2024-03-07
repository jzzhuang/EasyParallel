filename = "example_mc"
include("../src/Project.jl")

data = data_readout("0307-0930")
    # Output:
    # files detected: ["0307-0930_Jingze.dat"]
    # detect 50 iters, 40

sampled_avg = average(data)
    # This is in accordance with iters
    # iters = [(x, y) for x in 1:10 for y in 0.1:0.1:0.5]
