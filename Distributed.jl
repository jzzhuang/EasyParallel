using Distributed

addprocs(2)
@distributed for delay_time in [1, 1, 10, 10]
    println(delay_time); 
    sleep(delay_time);
end


using Distributed

addprocs(2)
pmap(delay_time ->(
        println(delay_time); 
        sleep(delay_time);
    ), 
    [1, 1, 1, 10, 10, 10])


function func()
    rand()
    ...
    return result
end

[func() for i in 1:1000]


function func(model)
    ...
    return result
end

models = [...]
[func(models[i]) for i in 1:1000]



addprocs(2)
@everywhere function func()
    x="Julia is the best language"
    println(x)
end
@everywhere [2, 3] func()
@everywhere include("Func.jl")

func()
println(x)

s=1
for i in 1:10
   s=i
end

using Distributed
addprocs(10)