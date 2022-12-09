@with_kw struct ParallelParam @deftype Bool
    num_repeat::Int = 1
    num_workers::Int = 100
    unpack = false
    ignore_wait = true
    dynam_sched = true
    Tout::DataType = Int64
    recover_timename::String = ""
end

function spawn(filename, procs_needed, parallel_param)
    @unpack_ParallelParam parallel_param

    if myid()!=1
        error("R U CRAZY")
    end

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

function read_process_num()
    parse(Int, read(pipeline(`ps -ef`, `grep -v grep`, `grep julia`, `wc -l`), String))
end

function wait_until_clear()
    i = 0
    while read_process_num()>360
        sleep(10)
        println(read_process_num())
        if i%100==0
            println("waited for $(i*10/3600) hrs")
        end
        i+=1
    end
end

mutable struct Subprocs_Utils
    last_save_hour::Int64
    start_hour::Int64
end

function parallel_main(i)
    global sub_count, sub_arr
    global iters
    global is_running

    if !is_running
        return 
    end

    if !isfile("$save_dir/data/is_running_$timename.mark")
        serialize(sub_filename, (sub_arr, sub_count))
        is_running = false
        return
    end

    print_to_file("$timename", "$(myid()), $i")
    result = subprocs_func(iters[i])

    push!(sub_count, i)
    push!(sub_arr, result)

    now_hour = Dates.hour(now())

    if (0 <= (now_hour - subprocs_utils.last_save_hour + 24) % 24 <= 20)
        serialize(sub_filename, (sub_arr, sub_count))
        subprocs_utils.last_save_hour = (now_hour + 1) % 24
    end
end


function parallel(filename::String, func::Function, iters, parallel_param)
    @unpack_ParallelParam parallel_param
    
    @assert iters isa Vector
    if (iters[1] isa Tuple) & !unpack
        println("Setting unpack = true")
        unpack = true
    end

    if iters == [nothing] # support iters=[]s
        iters = [()]
        unpack = true
    end
    
    println(); timename = gen_timename(); println();

    n_iters = length(iters)
    if recover_timename != ""
        tempfile = "$save_dir/$(recover_timename)_temp.dat"
        waited = 0
        while !isfile(tempfile)
            println("waiting for temp ", waited, " min")
            sleep(300); waited += 5
        end
        recover_arr, recover_count = deserialize(tempfile)

        need_iters = [max(0, num_repeat-count(==(i), recover_count)) for i in 1:n_iters]
        len_recover = length(recover_arr)
        @assert len_recover == length(recover_count)

        i_iters = reduce(vcat, [repeat([i], need_iters[i]) for i in 1:n_iters])
    else
        i_iters = repeat(collect(1:n_iters), num_repeat)
        recover_arr, recover_count = Tout[], Int64[]
    end

    
    procs_needed = n_iters * num_repeat
    num_workers = spawn(filename, procs_needed, parallel_param)

    @everywhere collect(2:num_workers+1) iters = $iters
    
    # unpack is necessary because func(large_array...) has non-allocating args
    if unpack
        @everywhere subprocs_func = x -> $func(x...)
    else
        @everywhere subprocs_func = $func
    end

    @everywhere subprocs_utils = Subprocs_Utils(Dates.hour(now()), Dates.hour(now()))
    @everywhere sub_count, sub_arr = Int64[], $Tout[]
    @everywhere timename, is_running = $timename, true
    @everywhere sub_filename = "$save_dir/data/$(timename)_procs$(myid())_temp.dat"

    if recover_timename != ""
        println("$(len_recover) data recovered from $recover_timename.dat.")
    end
    
    println("time name: $timename")
    println("num_workers: $num_workers")
    println("niters = $n_iters, num_repeat = $num_repeat")
    println("launch")

    touch("$save_dir/data/is_running_$timename.mark")
    
    if dynam_sched
        result = pmap(i->parallel_main(i), i_iters)
    else
        @sync @distributed for i in i_iters
            parallel_main(i)
        end
    end
    
    local_arr = [fetch(@spawnat i getfield(Main, :sub_arr)) for i in 2:num_workers+1]
    local_count = [fetch(@spawnat i getfield(Main, :sub_count)) for i in 2:num_workers+1]
    rmprocs(2:num_workers+1)

    println("Done.")

    all_arr = vcat(recover_arr, local_arr...)
    all_count = vcat(recover_count, local_count...)

    perm = sortperm(all_count); 
    result = all_arr[perm]
    
    println("Generate file $timename")
    
    is_running = isfile("$save_dir/data/is_running_$timename.mark")
    serialize("$save_dir/$(timename)$(is_running ? "" : "_temp").dat", (result, all_count[perm]))    

    for i in 2:num_workers+1
        tempfile = "$save_dir/data/$(timename)_procs$(i)_temp.dat"
        if isfile(tempfile)  
            rm(tempfile)  
        end
    end

    if is_running
        rm("$save_dir/data/is_running_$timename.mark")
    end

    return result
end

function average(arr, num_repeat)
    n = size(arr)[1] ÷ num_repeat

    result = [mean(selectdim(arr, 1, num_repeat*(i-1)+1:num_repeat*i), dims=1)[1] for i in 1:n]

    if length(result) == 1
        return result[1]
    else
        return result
    end
end

function read_intermediate(timename)
    num_workers = 1
    while isfile("$save_dir/data/$(timename)_procs$(num_workers+1)_temp.dat") 
        num_workers += 1
    end
    num_workers -= 1

    println("detect $num_workers workers")
    @time datas = [deserialize("$save_dir/data/$(timename)_procs$(i)_temp.dat") for i in 2:num_workers+1]
    recover_arr = vcat([data[1] for data in datas]...)
    recover_count = vcat([data[2] for data in datas]...)

    perm = sortperm(recover_count); recover_arr = recover_arr[perm];  recover_count = recover_count[perm]
    # (i-> (i-1) ÷ num_repeat + 1).(recover_count)
    return recover_arr, recover_count
end

function data_from_intermediate(timename, num_repeat)
    recover_arr, recover_count = read_intermediate(timename)

    len_iters = maximum(recover_count)
    println("detect $len_iters iters")
    count = zeros(Int, len_iters)
    for i_iters in recover_count
        count[i_iters] += 1
    end
    new_num_repeat = minimum(count)

    # count = 0
    iters_count = zeros(Int, len_iters)
    new_local_order = zeros(Int, len_iters*new_num_repeat)
    for i_iters in recover_count
        if iters_count[i_iters] >= new_num_repeat continue end
        iters_count[i_iters] += 1
        # count += 1
        new_local_order[(i_iters-1)*new_num_repeat + iters_count[i_iters]] = i#
    end
    return new_num_repeat, recover_arr[new_local_order]
end