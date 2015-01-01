function parse_str(str)
    ccall(:jl_parse_input_line, Any, (Ptr{Uint8},), str)
end

function is_incomplete(str)
    is_token(str) && (parse_str(str).head == :incomplete)
end

type LinesSaver
    parent::Union(Void, LinesSaver)
    lines::Array{String, 1}
    t::Symbol
end

LinesSaver(parent, lines) = LinesSaver(parent, lines, :evaluate)
LinesSaver(parent)        = LinesSaver(parent, String[])
LinesSaver()              = LinesSaver(nothing)

import Base.write
import Base.push!

function to_assignment(dic::Dict)
    line = String[]
    for (key, val) in dic
        if typeof(val) <: String
            push!(line, "$key=\"$val\"")
        else
            push!(line, "$key=$val")
        end
    end

    join(reverse(line), "\n")
end

# suppose the reg is a 'matched' reg
offset(reg::Regex) = reg.ovec[1] + 1

function matched(reg::Regex, str)
    SubString(str, reg.ovec[3] + 1, reg.ovec[4])
end


function is_token(str)
    ismatch(r"<%.*%>", str)
end

function is_end_token(str)
    ismatch(r"<%\s*end\s*%>", str)
end

settings = {:evaluate =>  r"<%([\s\S]+?)%>",
            :interpolate => r"<%=([\s\S]+?)%>"}

function is_evaluate(str)
    !ismatch(settings[:interpolate], str) && ismatch(settings[:evaluate], str)
end

function is_interpolate(str)
    ismatch(settings[:interpolate], str)
end

function parse_template(str)
    matcher = Regex(join([settings[:evaluate].pattern,
                          settings[:interpolate].pattern, "\$"],
                         "|"))

    str_length = length(str)

    index = 1

    lines_saver = LinesSaver(nothing)

    current_liens_saver = lines_saver

    function repl(m)
        offset_ = offset(matcher)
        if index != 1 && index != str_length
            # index to offset is a gap
            # so before the gap, it is matched
            # no matter which kinds of match, the first "\n" should not take into consideration
            # so remove it by shift index
            index = search(str, r"\S", index)[1]
        end

        line = "write(io,\"" * str[index: offset_ - 1] * "\")\n"

        push!(current_liens_saver.lines, line)

        index = offset_ + length(m)

        if is_evaluate(m)
            line = matched(settings[:evaluate], m) * "\n"

            if is_incomplete(m)
                current_liens_saver = LinesSaver(current_liens_saver)
            elseif is_end_token(m)
                push!(current_liens_saver.lines, line)

                if current_liens_saver.t == :interpolate
                    line = "write(io, string(" * join(current_liens_saver.lines) * "))"
                else
                    line = join(current_liens_saver.lines)
                end

                current_liens_saver = current_liens_saver.parent
            end

            push!(current_liens_saver.lines, line)
        elseif is_interpolate(m)
            matched_ = matched(settings[:interpolate], m)
            if is_incomplete(m)
                current_liens_saver = LinesSaver(current_liens_saver, String[], :interpolate)
                line = matched_
            else
                line = "write(io, string($matched_))\n"
            end

            push!(current_liens_saver.lines, line)
        end
    end

    replace(str, matcher, repl)

    join(current_liens_saver.lines)
end

function render(str, dic::Dict)
    assignment_line = to_assignment(dic)
    (()-> begin
        eval(parse_str( assignment_line * "\nio = IOBuffer()\n " * parse_template(str) * " \nio"))
    end)()
end

render(str) = render(str, Dict{Any, Any}())
