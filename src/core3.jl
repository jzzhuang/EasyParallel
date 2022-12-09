# unpack is necessary because func(large_array...) has non-allocating args
if unpack
    @everywhere subprocs_func = x -> $func(x...)
else
    @everywhere subprocs_func = $func
end

@everywhere sub_count, sub_arr = Int64[], $Tout[]
@everywhere sub_filename = "$save_dir/data/$(timename)_procs$(myid())_temp.dat"

function parallel_main(i)
    global iters, sub_count, sub_arr
    global is_running

    if !is_running return end

    if !isfile("$save_dir/data/is_running_$timename.mark")
        serialize(sub_filename, (sub_arr, sub_count))
        is_running = false
        return
    end

    result = subprocs_func(iters[i])

    push!(sub_count, i); push!(sub_arr, result)

    now_hour = Dates.hour(now())

    if (0 <= (now_hour - subprocs_utils.last_save_hour + 24) % 24 <= 20)
        serialize(sub_filename, (sub_arr, sub_count))
        subprocs_utils.last_save_hour = (now_hour + 1) % 24
    end
end

