function print_to_file(str...)
    open("$save_dir/log.txt","a") do iol
        println(iol, str...)
    end
end

function print_to_filename(filename, str...)
    open("$save_dir/$(filename)_log.txt","a") do iol
        println(iol, str...)
    end
end

