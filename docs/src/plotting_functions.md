# Plotting Functions

On this page, the basic plotting functions are listed together with examples of their usage and available attributes.

## `contourf`

```@docs
contourf
```

### Examples

```@example
using Makie

xs = LinRange(0, 10, 100)
ys = LinRange(0, 10, 100)
zs = [cos(x) * sin(y) for x in xs, y in ys]

contourf(xs, ys, zs, levels = 10)
```
