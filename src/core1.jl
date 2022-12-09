procs_needed = n_iters * num_repeat

function spawn(filename, procs_needed, parallel_param)
    num_workers = min(procs_needed, num_workers)
    
    if length(workers()) == 1
        add_workers = num_workers
    elseif length(workers()) < num_workers 
        add_workers = num_workers - length(workers())
    else
        add_workers = 0
    end
    addprocs(add_workers) 

    @everywhere collect(2:num_workers+1) include("src/InfoClifford.jl")
    if filename != "temp"
        @everywhere collect(2:num_workers+1) include($filename*".jl")
    end

    return length(workers())
end

