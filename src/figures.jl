using AbstractPlotting
using AbstractPlotting.MakieLayout
using CairoMakie
CairoMakie.activate!()

struct Figure
    scene::Scene
    layout::GridLayout
    content::Vector{Any}
end

struct FigureSlot
    f::Figure
    span::MakieLayout.GridLayoutBase.Span
    side::MakieLayout.GridLayoutBase.Side
end

Base.getindex(f::Figure, rows, cols, side = MakieLayout.GridLayoutBase.Inner()) =
    FigureSlot(f,
        MakieLayout.GridLayoutBase.Span(
            MakieLayout.GridLayoutBase.to_ranges(f.layout, rows, cols)...
        ),
        side)

# overwrite `plot` to emit a figure instead of a scene
function AbstractPlotting.plot(P::Type{<:AbstractPlot}, args...; kwargs...)
    kwargs = Dict(kwargs)
    scene, layout = layoutscene(; pop!(kwargs, :scenekw, (;))...)
    f = Figure(scene, layout, [])
    ax, p = plot!(P, f[1, 1], args...; kwargs...)
    (figure = f, ax = ax, plot = p)
end


function AbstractPlotting.plot!(p::Type{<:AbstractPlot}, fs::FigureSlot, args...; kwargs...)
    f = fs.f
    layout = f.layout
    span = fs.span
    side = fs.side

    gp = GridPosition(layout, span, side)
    cs = contents(gp)

    kwargs = Dict(kwargs)
    axkw = pop!(kwargs, :axkw, (;))

    created_axis = false
    # behavior depends on what exists at the given location already
    if isempty(cs)
        ax = layout[span.rows, span.cols, side] = LAxis(f.scene; axkw...)
        push!(f.content, ax)
        created_axis = true
    elseif length(cs) == 1
        ax = cs[1]
        !isempty(axkw) && error("Passed axis keywords but axis at $span $side already existed.")
        ax isa LAxis || error("Element at $span $(side) is not an LAxis and can't be plotted in.")
    else
        error("More than one element at $span $(side), can't plot into that position automatically.")
    end
    
    p = plot!(p, ax, args...; kwargs...)

    # return type depends on if an axis was created or not
    if created_axis
        return (axis = ax, plot = p)
    else
        return p
    end
end


Base.display(nt::NamedTuple{<:Any, <:Tuple{Figure, Any, Any}}) = Base.display(nt.figure.scene)

##
fig, ax, hm = heatmap(randn(20, 20),
    scenekw = (resolution = (600, 600), fontsize = 12),
    axkw = (xtickformat = "{:.2f}", xticksize = 3))

ax, s = scatter!(fig[1, 2], randn(100, 2); axkw = (title = "hello",))
scatter!(ax, randn(100, 2) .+ 5, color = :blue)
ax, lins = lines!(fig[2, 1:2], 0..20, sin)
lines!(ax, 0..20, cos, color = :red)
fig

##

