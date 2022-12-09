if !(@isdefined myid)
    using Distributed
    using Plots, LaTeXStrings, MathLink
end
using Serialization, Random
using Parameters

include("core1.jl")
include("core2.jl")
include("parallel.jl")

if !(@isdefined filename)
    filename = "temp"
    if myid()==1
        println("filename not defined")
    end
end

save_dir = "/data/$filename"
plot_dir = "/$filename"

if !isdir(save_dir)
    create_directory(save_dir)
end



function check_dir(save_dir, plot_dir)
    if !isdir(save_dir)
        println("$save_dir not exists, create?")
        readline()
        mkdir(save_dir)
        mkdir(save_dir*"/data")
        mkdir(save_dir*"/data/temp")
    end
    if !isdir(plot_dir)
        println("$plot_dir not exists, create?")
        readline()
        mkdir(plot_dir)
    end
end

function gen_timename()
    timename = "$(Dates.format(now(), "mmdd-HHMM"))"
    println("generate time name: $timename")
    return timename
end

check_dir(save_dir, plot_dir)