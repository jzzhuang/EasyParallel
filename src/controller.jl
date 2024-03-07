@with_kw struct ParallelParam @deftype Bool
    num_repeat::Int = 1
    num_workers::Int = -1
    unpack = false
    ignore_wait = false
    dynam_sched = true
    Tout::DataType = Float64
    recover_timename::String = ""
    test_mode = false
    silent_mode = false
    num_batch::Int = 1
    num_threads::Int = 1
end

function create_parallel_param(; num_batch = 1, Tout = Int64, num_workers = num_workers, kwargs...)
    (myid() != 1) ? (return nothing) : nothing

    if num_workers == -1
        num_workers = @match server_name begin
            "_" => 2
        end
    end

    if (num_batch > 1) && ((Tout==Int) || (Tout <: Array{Int, N} where N))
        println("Warning: num_batch > 1, but Tout = $Tout.")
        if Tout == Int
            Tout = Float64
        elseif Tout <: Array{Int, N} where N
            Tout = Array{Float64, ndims(Tout)}
        end
    end
    return ParallelParam(; num_batch = num_batch, Tout = Tout, num_workers = num_workers, kwargs...)
end


is_running_filename(save_dir, server_name, timename) = "$save_dir/data/is_running_$(server_name)_$timename.mark"

function spawn(filename, startfilename, procs_needed, parallel_param)
    @unpack_ParallelParam parallel_param

    if myid()!=1
        error("R U CRAZY")
    end

    if (!ignore_wait) && (!test_mode)
        wait_until_clear()
    end

    num_workers = min(procs_needed, num_workers)
    
    if length(workers()) == 1
        add_workers = num_workers
    elseif length(workers()) < num_workers 
        add_workers = num_workers - length(workers())
    else
        add_workers = 0
    end

    if test_mode 
        addprocs(1, exeflags = "--project=$(Base.active_project())")
    else
        addprocs(add_workers, exeflags = "--project=$(Base.active_project())") 
    end

    if filename != "temp"
        @everywhere workers() include($startfilename)
    end
    @everywhere BLAS.set_num_threads($(num_threads))

    return length(workers())
end

function read_process_num()
    parse(Int, read(pipeline(`ps -ef`, `grep -v grep`, `grep julia`, `wc -l`), String))
end

function wait_until_clear()
    i = 0
    while read_process_num() - length(workers())>5
        sleep(10)
        if i%100==0
            println(read_process_num())
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

    if !isfile(is_running_filename(save_dir, server_name, timename))
        serialize(sub_filename, (sub_arr, sub_count))
        is_running = false
        return
    end    

    print_to_file("$timename", " $(myid()), $i")

    if num_batch > 1
        result = mean([subprocs_func(iters[i]) for _ in 1:num_batch])
    else
        result = subprocs_func(iters[i])
    end

    push!(sub_count, i)
    push!(sub_arr, result)

    now_hour = Dates.hour(now())

    if now_hour != subprocs_utils.last_save_hour
        serialize(sub_filename, (sub_arr, sub_count))
        subprocs_utils.last_save_hour = now_hour

        if server_name == "amax" return end
        sentmark = "$save_dir/data/sent_$(timename)_$(server_name)_$now_hour.mark"
        sentmark_previous = "$save_dir/data/sent_$(timename)_$(server_name)_$((now_hour-3+24)%24).mark"
        if !isfile(sentmark)
            touch(sentmark)
            if isfile(sentmark_previous)
                rm(sentmark_previous)
            end
            temp_filename = "$save_dir/$(timename)_$(server_name)_temp.dat"
            serialize(temp_filename, read_intermediate(timename, false))
            send_to_tsinghua(temp_filename, "$(timename)_$(server_name)")
            rm(temp_filename)
        end
    end
end


function parallel(filename::String, startfilename::String, func::Function, iters, parallel_param)
    @unpack_ParallelParam parallel_param
    
    @assert iters isa Vector
    if (iters[1] isa Tuple) & !unpack
        println("Tuple in iters, but unpack is false. Setting unpack = true")
        unpack = true
    end

    if iters == [nothing] # support iters=[]s
        iters = [()]
        unpack = true
    end

    
    
    timename = @match server_name begin
        _ => gen_timename()
    end

    if test_mode
        println("test mode, set num iters = 1")
        num_repeat = 1
    end
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

        i_iters = repeat(collect(1:n_iters), minimum(need_iters))
        need_iters = need_iters .- minimum(need_iters)
        i_iters = vcat(i_iters, reduce(vcat, [repeat([i], need_iters[i]) for i in 1:n_iters]))
    else
        i_iters = repeat(collect(1:n_iters), num_repeat)
        recover_arr, recover_count = Tout[], Int64[]
    end

    
    procs_needed = n_iters * num_repeat
    num_workers = spawn(filename, startfilename, procs_needed, parallel_param)
    all_workers = workers()

    @everywhere all_workers iters = $iters
    
    # unpack is necessary because func(large_array...) has non-allocating args
    if unpack
        @everywhere subprocs_func = x -> $func(x...)
    else
        @everywhere subprocs_func = $func
    end

    @everywhere subprocs_utils = Subprocs_Utils(Dates.hour(now()), Dates.hour(now()))
    @everywhere sub_count, sub_arr = Int64[], $Tout[]
    @everywhere timename, is_running, server_name, num_batch = $timename, true, $server_name, $num_batch
    @everywhere sub_filename = "$save_dir/data/$(timename)_$(server_name)_procs$(myid())_temp.dat"

    if recover_timename != ""
        println("$(len_recover) data recovered from $recover_timename.dat.")
    end
    
    println("time name: $timename")
    println("num_workers: $num_workers")
    println("niters = $n_iters, num_repeat = $num_repeat")
    println("launch")

    isrun_mark_filename = is_running_filename(save_dir, server_name, timename)
    touch(isrun_mark_filename)
    
    if dynam_sched
        result = pmap(i->parallel_main(i), i_iters)
    else
        @sync @distributed for i in i_iters
            parallel_main(i)
        end
    end
    
    local_arr = [fetch(@spawnat i getfield(Main, :sub_arr)) for i in all_workers]
    local_count = [fetch(@spawnat i getfield(Main, :sub_count)) for i in all_workers]
    rmprocs(all_workers)

    println("Done.")

    all_arr = vcat(recover_arr, local_arr...)
    all_count = vcat(recover_count, local_count...)

    perm = sortperm(all_count); 
    result = all_arr[perm]
    
    println("Generate file $timename")
    
    is_running = isfile(isrun_mark_filename)
    if !silent_mode
        save_filename = "$save_dir/$(timename)_$(server_name).dat"
        serialize(save_filename, (result, all_count[perm]))
        
        # if server_name == "***"
        #     send_to_main(save_filename, "$(timename)_$(server_name)")
        # end
    end
    
    for i in all_workers
        tempfile = "$save_dir/data/$(timename)_$(server_name)_procs$(i)_temp.dat"
        if isfile(tempfile)  
            rm(tempfile)  
        end
    end

    if is_running
        rm(isrun_mark_filename)
    end


    if test_mode
        println(result)
    end
    return result
end

function merge(data_n_1, data_n_2)
    data1, n1 = data_n_1
    data2, n2 = data_n_2

    if n1 == 0 return data_n_2 end
    if n2 == 0 return data_n_1 end
    
    niters = Int(length(data1)/n1)
    return (vcat([vcat(data1[n1*(i-1)+1:n1*i], data2[n2*(i-1)+1:n2*i]) for i in 1:niters]...), n1+n2)
end

function merge(datas)
    if length(datas)==1
        return datas[1]
    end
    if length(datas)==0
        return datas
    end
    data_result = datas[1]
    for i in 2:length(datas)
        data_result = merge(data_result, datas[i])
    end
    return data_result
end

function average(data)
    map_data(mean, data...)     
end


function average(args...)
    error("Wrong argument")
end

function map_data(func, arr, num_repeat)     
    n = size(arr)[1] ÷ num_repeat

    result = [func(selectdim(arr, 1, num_repeat*(i-1)+1:num_repeat*i)) for i in 1:n]

    if length(result) == 1
        return result[1]
    else
        return result
    end
end

function map_data_iter(func, arr, num_repeat)     
    n = size(arr)[1] ÷ num_repeat

    result = [func(i, selectdim(arr, 1, num_repeat*(i-1)+1:num_repeat*i)) for i in 1:n]

    if length(result) == 1
        return result[1]
    else
        return result
    end
end

is_data_file(filename, timename) = startswith(filename, timename) && endswith(filename, ".dat")
is_data_file(filename, server_name, timename) = startswith(filename, "$(timename)_$(server_name)") && endswith(filename, ".dat")

function read_intermediate(timename, verbose = true)
    filenames = readdir("$save_dir/data")
    matched_files = [filename for filename in filenames if is_data_file(filename, server_name, timename)]
    if verbose
        println("detect $(length(matched_files)) workers")
    end

    time_taken = @elapsed datas = [deserialize("$save_dir/data/$filename") for filename in matched_files]
    if time_taken>5 println("read intermediate time taken: $time_taken") end
    recover_arr = vcat([data[1] for data in datas]...)
    recover_count = vcat([data[2] for data in datas]...)

    perm = sortperm(recover_count); recover_arr = recover_arr[perm];  recover_count = recover_count[perm]
    # (i-> (i-1) ÷ num_repeat + 1).(recover_count)
    return recover_arr, recover_count
end

function data_readout(timename::String)
    filenames = readdir("$save_dir")
    savedfiles = [filename for filename in filenames if is_data_file(filename, timename)]
    println("files detected: $(savedfiles)")
    data_savedfiles = [data_recov_proc(deserialize("$save_dir/$filename")) for filename in savedfiles]
    data_intermediate = data_recov_proc(read_intermediate(timename, length(savedfiles) == 0))

    data = merge(vcat(data_savedfiles, data_intermediate))
    
    return data
end

function data_readout(filename::String, timename::String)
    dir = "$save_dir/../$filename"
    original_save_dir = save_dir
    global save_dir = dir
    data = data_readout(timename)
    global save_dir = original_save_dir
    return data
end

function data_recov_proc(data_recover)
    if (typeof(data_recover[2])==Int) || (typeof(data_recover)<:Vector)
        warning("older format of data")
        return data_recover
    end

    recover_arr, recover_count = data_recover
    if length(recover_arr) == 0 
        return recover_arr, 0
    end
    len_iters = maximum(recover_count)
    count = zeros(Int, len_iters)
    for i_iters in recover_count
        count[i_iters] += 1
    end
    new_num_repeat = minimum(count)
    println("detect $len_iters iters, $new_num_repeat")

    # count = 0
    iters_count = zeros(Int, len_iters)
    new_local_order = zeros(Int, len_iters*new_num_repeat)
    for (i, i_iters) in enumerate(recover_count)
        i_iters = recover_count[i]
        if iters_count[i_iters] >= new_num_repeat continue end
        iters_count[i_iters] += 1
        # count += 1
        new_local_order[(i_iters-1)*new_num_repeat + iters_count[i_iters]] = i#
    end
    return recover_arr[new_local_order], new_num_repeat
end

function send_to_main(save_filename, main_filename)
    @assert (server_name == "node78" || server_name == "node79")
    run(`scp $save_filename tsing:$save_dir_main/$main_filename.dat`)
end

function stop_timename(timename)
    isrun_mark_filename = is_running_filename(save_dir, server_name, timename)
    if isfile(isrun_mark_filename)
        rm(isrun_mark_filename)
        println("stopped $timename on $server_name at $save_dir")
    else
        println("not running: $timename on $server_name at $save_dir")
    end
end