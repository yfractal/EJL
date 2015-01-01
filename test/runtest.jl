using FactCheck
include("../src/EJL.jl")

facts("is_token") do
    @fact is_token("<% %>") => true
    @fact is_token("<% ") => false
    @fact is_token("<%= %>") => true
end

facts("is_end_token") do
    @fact is_end_token("<% end %>") => true
    @fact is_end_token("<% print %>") => false
    @fact is_end_token("<% end_ %>") => false
    @fact is_end_token("<% end a %>") => false
    @fact is_end_token("<%end%>") => true
end

facts("inject the variables") do
    context("to_assignment") do
        @fact to_assignment({:a => 1}) => "a=1"
        @fact to_assignment({:a => 1, :b => 2}) => "a=1\nb=2"
    end
end

facts("offset of reg") do
    context("match") do
        str = "nyn"
        reg = r"y"
        match(reg, str)
        @fact offset(reg) => 2
    end
    context("replace") do
        str = "nyny"
        reg = r"y"
        replace(str, reg, "")
        @fact offset(reg) => 4
    end
end

facts("parse_template") do
    context("str") do
        @fact parse_template("a") => "write(io,\"a\")\n"
        @fact parse_template("a\n") => "write(io,\"a\")\nwrite(io,\"\n\")\n"
        @fact parse_template("\na\n") => "write(io,\"\na\")\nwrite(io,\"\n\")\n"
        @fact parse_template("a\n\b\n") => "write(io,\"a\n\b\")\nwrite(io,\"\n\")\n"

    end

    context("str with evalute") do
        @fact parse_template("a<% e %>") => "write(io,\"a\")\n e \n"
        @fact parse_template("a\n<% e %>") => "write(io,\"a\n\")\n e \n"
        @fact parse_template("a<% e %>a") => "write(io,\"a\")\n e \nwrite(io,\"a\")\n"
    end

    context("mulpitle lines") do
        input = join(["<% for i in [1, 2, 3] %>", "for", "<%end%>"], "\n")
        @fact parse_template(input) => "write(io,\"\")\n for i in [1, 2, 3] \nwrite(io,\"for\n\")\nend\n"
    end

    context("interpolate") do
        @fact parse_template("<%= e %>") => "write(io,\"\")\nwrite(io, string( e ))\n"
        @fact parse_template("a<%= e %>") => "write(io,\"a\")\nwrite(io, string( e ))\n"
        @fact parse_template("a<%= e %>a") => "write(io,\"a\")\nwrite(io, string( e ))\nwrite(io,\"a\")\n"
    end

    context("interpolate nest") do
        input = join(["<%= for i in [1, 2, 3] %>", "for", "<%end%>"], "\n")
        @fact parse_template(input) => "write(io,\"\")\nwrite(io, string( for i in [1, 2, 3] write(io,\"for\n\")\nend\n))"
    end
end

facts("is_evaluate") do
    @fact is_evaluate("<% e %>") => true
    @fact is_evaluate("<%= e %>") => false
end

facts("matched") do
    str = "<% e %>"
    reg = r"<%([\s\S]+?)%>"
    match( reg, str)
    @fact matched(reg, str) => " e "
end

type Foo f end

facts("render") do
    context("simple case") do
        str = "<%= e %>"
        @fact takebuf_string( render(str, Dict{Any,Any}(:e => 1)) ) => "1"
    end
    context("for loop") do
        str =
        "<% for i in [1,2,3] %> \n" *
        "<%= repeat %>\n" *
        "<% end %>"
        @fact takebuf_string( render(str, Dict{Any,Any}(:repeat => 1)) ) => "111"
        @fact takebuf_string( render(str, Dict{Any,Any}(:repeat => "rep")) ) => "repreprep"
    end
    context("interpolated for loop") do
        str =
        "<%= for i in [1,2,3] %> \n" *
        "<%= repeat %>\n" *
        "<% end %>"
        @fact takebuf_string( render(str, Dict{Any,Any}(:repeat => "rep")) ) => "repreprepnothing"
    end
    context("conditional") do
        context("") do
            str =
            "<% if true %>\n" *
               "true\n" *
            "<% else %>\n" *
               "false\n" *
            "<% end %>"
            @fact takebuf_string( render(str)) => "true\n"
        end
        context(" with eval") do
            str =
            "<% if (i == 1) %>\n" *
               "true\n" *
            "<% else %>\n" *
               "false\n" *
            "<% end %>"
            @fact takebuf_string( render(str, Dict{Any, Any}(:i => 1))) => "true\n"
            @fact takebuf_string( render(str, Dict{Any, Any}(:i => 2))) => "false\n"
        end
    end
    context("assignment in template") do
        str =
        "<% a = 1 %>\n" *
        "<%= a %>"
        @fact takebuf_string( render(str)) => "1"
    end
    context("type") do
        str =
        "<%= foo.f %>"
        @fact takebuf_string( render(str, Dict{Any, Any}(:foo => Foo(1) ))) => "1"
    end
end
