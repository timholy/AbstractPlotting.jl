@recipe(Contourf) do scene
    Theme(
        levels = 10,
        colormap = :viridis,
    )
end


function AbstractPlotting.plot!(c::Contourf{<:Tuple{Any, Any, Any}})
    xs, ys, zs = c[1:3]

    levels = lift(zs, c.levels) do zs, levels
        mi, ma = extrema(zs)

        return if levels isa Int
            collect(LinRange(mi, ma, levels+1))
        elseif levels isa AbstractVector
            collect(levels)
        else
            error("$levels is an invalid level setting")
        end
    end


    polynode = lift(xs, ys, zs, levels) do xs, ys, zs, levels
        lows, highs = levels[1:end-1], levels[2:end]
        isos = Isoband.isobands(xs, ys, zs, lows, highs)

        allvertices = Point2f0[]
        allfaces = NgonFace{3,OffsetInteger{-1,UInt32}}[]
        allids = Int[]

        # TODO: this is ugly
        polys = typeof(Polygon(rand(Point2f0, 3), [rand(Point2f0, 3)]))[]
        # @show typeof(polys)

        foreach(enumerate(isos)) do (i, group)

            points = Point2f0.(group.x, group.y)
            polygroups = _group_polys(points, group.id)


            # nv = length(allvertices)

            for polygroup in polygroups

                outline = polygroup[1]
                holes = polygroup[2:end]

                # TODO this is horrible, fix needed in GeometryBasics for empty interiors
                poly = GeometryBasics.Polygon(outline, isempty(holes) ? [rand(Point2f0, 0)] : holes)

                push!(polys, poly)
            end
        end

        GeometryBasics.MultiPolygon(polys)

        
        # (allvertices, allfaces, allids)
    end

    mesh!(c, polynode, shading = false,
        colormap = c.colormap, color = 1:length(polynode[].polygons))
    c
end


function _group_polys(points, ids)

    polys = [points[ids .== i] for i in unique(ids)]
    npolys = length(polys)

    polys_lastdouble = [push!(p, first(p)) for p in polys]

    # this matrix stores whether poly i is contained in j
    # because the marching squares algorithm won't give us any
    # intersecting or overlapping polys, it should be enough to
    # check if a single point is contained, saving some computation time
    containment_matrix = [
        p1 != p2 &&
        PolygonOps.inpolygon(first(p1), p2) == 1
        for p1 in polys_lastdouble, p2 in polys_lastdouble]

    unclassified_polyindices = collect(1:size(containment_matrix, 1))
    # @show unclassified_polyindices

    # each group has first an outer polygon, and then its holes
    # TODO: don't specifically type this 2f0?
    groups = Vector{Vector{Point2f0}}[]

    # a dict that maps index in `polys` to index in `groups` for outer polys
    outerindex_groupdict = Dict{Int, Int}()

    # all polys have to be classified
    while !isempty(unclassified_polyindices)
        to_keep = ones(Bool, length(unclassified_polyindices))

        # println("containment matrix")
        # display(containment_matrix)

        # go over unclassifieds and find outer polygons in the remaining containment matrix
        for (ii, i) in enumerate(unclassified_polyindices)
            # an outer polygon is not inside any other polygon of the matrix
            if sum(containment_matrix[ii, :]) == 0
                # an outer polygon
                # println(i, " is an outer polygon")
                push!(groups, [polys_lastdouble[i]])
                outerindex_groupdict[i] = length(groups)
                # delete this poly from further rounds
                to_keep[ii] = false
            end
        end

        # go over unclassifieds and find hole polygons
        for (ii, i) in enumerate(unclassified_polyindices)
            # the hole polygons can only be in one polygon from the current group
            # if they are in more than one, they are "inner outer" or inner hole polys
            # and will be handled in one of the following passes
            if sum(containment_matrix[ii, :]) == 1
                outerpolyindex_of_unclassified = findfirst(containment_matrix[ii, :])
                outerpolyindex = unclassified_polyindices[outerpolyindex_of_unclassified]
                # a hole
                # println(i, " is an inner polygon of ", outerpolyindex)
                groupindex = outerindex_groupdict[outerpolyindex]
                push!(groups[groupindex], polys_lastdouble[i])
                # delete this poly from further rounds
                to_keep[ii] = false
            end
        end
    
        unclassified_polyindices = unclassified_polyindices[to_keep]
        containment_matrix = containment_matrix[to_keep, to_keep]
    end
    groups
end