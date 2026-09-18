// The same idea in OpenSCAD's own language, for when a part is simple enough
// that a DSL beats Python — and so you can open and remix the enormous body of
// existing .scad designs.
//
//   openscad part.scad                  GUI; enable Design → Automatic Reload and Preview
//   openscad -o build/part.stl part.scad   headless export
//
// OpenSCAD is mesh/CSG: it exports STL/3MF/OFF, but not STEP. Use model.py when
// you need a B-rep for CNC, or true fillets.

/* [Plate] */
length = 60;   // [20:120]
width  = 40;   // [20:120]
thick  = 5;    // [2:20]
corner = 4;    // [0:10]

/* [Holes] */
hole_d = 5.5;
inset  = 10;

$fn = 64;

module rounded_plate(l, w, t, r) {
    hull()
        for (x = [r, l - r], y = [r, w - r])
            translate([x, y, 0]) cylinder(h = t, r = r);
}

difference() {
    rounded_plate(length, width, thick, corner);
    for (y = [width / 4, 3 * width / 4])
        translate([length - inset, y, -1])
            cylinder(h = thick + 2, d = hole_d);
}
