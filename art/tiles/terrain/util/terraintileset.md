# Terrain Tileset Layout

Each named terrain PNG is **96×192 px** — 3 columns × 6 rows of 32×32 px tiles.

## Tile grid (col × row)

| Row | Col 1         | Col 2            | Col 3            |
|-----|---------------|------------------|------------------|
| 1   | small         | inner corner TL  | inner corner TR  |
| 2   | small2        | inner corner BL  | inner corner BR  |
| 3   | corner TL     | wall top         | corner TR        |
| 4   | wall left     | solid            | wall right       |
| 5   | corner BL     | wall bottom      | corner BR        |
| 6   | solid alt1    | solid alt2       | solid alt3       |

## Offset table (index within the 1024-tile atlas row)

Offsets are added to the set's **start tile** to locate each cell.
The atlas has 32 tiles per row, so each new row of the set is +32.

| Row | Col 1 offset | Col 2 offset | Col 3 offset |
|-----|-------------|-------------|-------------|
| 1   | +0          | +1          | +2          |
| 2   | +32         | +33         | +34         |
| 3   | +64         | +65         | +66         |
| 4   | +96         | +97         | +98         |
| 5   | +128        | +129        | +130        |
| 6   | +160        | +161        | +162        |

## Tile meanings

| Name             | Meaning                                                      |
|------------------|--------------------------------------------------------------|
| solid            | Fully filled interior tile                                   |
| solid alt1/2/3   | Visual variants of the solid fill (detail/noise)             |
| small            | Small decorative fill variant                                |
| small2           | Second small decorative fill variant                         |
| wall top         | Top edge — material below, void above                        |
| wall bottom      | Bottom edge — material above, void below                     |
| wall left        | Left edge — material right, void left                        |
| wall right       | Right edge — material left, void right                       |
| corner TL        | Convex top-left corner (material in bottom-right quadrant)   |
| corner TR        | Convex top-right corner (material in bottom-left quadrant)   |
| corner BL        | Convex bottom-left corner (material in top-right quadrant)   |
| corner BR        | Convex bottom-right corner (material in top-left quadrant)   |
| inner corner TL  | Concave corner — terrain tip points TL, void diagonal at BR  |
| inner corner TR  | Concave corner — terrain tip points TR, void diagonal at BL  |
| inner corner BL  | Concave corner — terrain tip points BL, void diagonal at TR  |
| inner corner BR  | Concave corner — terrain tip points BR, void diagonal at TL  |

## Inner corner selection rule (for code)

Use **INNER_XY** when the diagonal neighbour in the **opposite** direction is void:

| Void diagonal | Use tile   |
|---------------|------------|
| top-right     | INNER_BL   |
| top-left      | INNER_BR   |
| bottom-right  | INNER_TL   |
| bottom-left   | INNER_TR   |
