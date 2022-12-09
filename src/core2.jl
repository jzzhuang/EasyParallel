function parallel(filename::String, func::Function, iters, parallel_param)
    if (myid()!=1)  exit() end

    spawn(filename, procs_needed, parallel_param)

    if dynam_sched
        pmap(i->parallel_main(i), i_iters)
    else
        @sync @distributed for i in i_iters
            parallel_main(i)
        end
    end

    arr = [fetch(@spawnat i getfield(Main, :sub_arr)) for i in 2:num_workers+1]
    count = [fetch(@spawnat i getfield(Main, :sub_count)) for i in 2:num_workers+1]
    rmprocs(2:num_workers+1)

    println("Done.")

    serialize("$save_dir/$(timename)$(is_running ? "" : "_temp").dat", (arr, count))    
end


