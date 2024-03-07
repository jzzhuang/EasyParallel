if !(@isdefined filename)
    filename = "temp"
    if myid()==1
        println("filename not defined, set to temp")
    end
end

# Future: structure the server configuration as a struct: server_capacity, save_dir, plot_dir, etc.

global server_name = gethostname()
global save_dir, plot_dir = 
@match server_name begin
    _ =>               ("data/$filename",      "data/$filename")
end

# For remote worker, we want the data to be sent back to the main server
global save_dir_main = "/***/data/$filename"


function check_dir(save_dir, plot_dir)
    if !isdir(save_dir)
        println("$save_dir not exists, create?")
        readline()
        mkdir(save_dir)
        mkdir(save_dir*"/data")
    end
    if !isdir(plot_dir)
        println("$plot_dir not exists, create?")
        readline()
        mkdir(plot_dir)
    end

    if !isdir(save_dir*"/data")
        error("dir check failed: $(save_dir*"/data")")
    end
end

function gen_timename()
    timename = "$(Dates.format(now(), "mmdd-HHMM"))"
    println(); println("generate timename: $timename"); println()
    return timename
end
check_dir(save_dir, plot_dir)
