# ellipsize_path
#
# Params:
#  $1: max length
function ellipsized_path() {
    local max_size=${1:-40}
    local cwd=$(print -Pn '%~')
    local cwd_array=(${(s:/:)${cwd}})
    local elements=${#cwd_array}
    local head=$(( elements / 2 ))
    local tail=$(( elements - head ))
    local separator="/"

    # Reduce the number of elements until the path fits, while keeping at least 2 leading and
    # 2 trailing elements.
    while (( ${#cwd} > max_size && head >= 2 && tail >= 2 )) {
        if (( head + tail < elements )) {
            separator='/…/'
        }
        cwd=$(print -P "%-${head}~${separator}%${tail}~")
        if (( head == tail )) {
            head=$(( head - 1 ))
        } else {
            tail=$(( tail - 1 ))
        }
    }
    # If the path is still too long, ellipsize the largest elements until it fits.
    while (( ${#cwd} > max_size )) {
        cwd_array=(${(s:/:)${cwd}})
        elements=${#cwd_array}
        local largest_index=1
        local largest=${cwd_array[1]}
        for (( i=1; i <= elements; i++ )) {
            if (( ${#cwd_array[i]} > ${#largest} )) {
                largest_index=$i
                largest=${cwd_array[i]}
            }
        }
        if [[ $largest != *… ]] {
            cwd_array[largest_index]=${largest//??(#e)/…}
        } else {
            (( ${#largest} > 1 )) && \
                cwd_array[largest_index]=${largest//?…(#e)/…}
        }
        cwd=${(j:/:)cwd_array}                      # Convert array to string
        # Coalesce adjacent ellipses if possible.
        while [[ $cwd = *((#s)|/)…/…((#e)|/)* ]] {
            cwd=${${cwd}//\/…\/…\//\/…\/}
            cwd=${${cwd}//(#s)…\/…\//…\/}
            cwd=${${cwd}//\/…\/…(#e)/\/…}
        }
    }
    print -n "$cwd"
}

ellipsized_path
