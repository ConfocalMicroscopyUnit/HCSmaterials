/*
 * This macro creates a binary image containing the objects that are brighter than 311 arbitrary units, bigger than 189 pixels, smaller
 * than 1701 pixels and whose circularity is bigger than 0.59. Objects holes are filled prior to implementig a watershed algorithm.
 */
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
setThreshold(312, 65535);
setOption("BlackBackground", true);
run("Convert to Mask");
run("Fill Holes");
run("Watershed");
run("Analyze Particles...", "size=190-1700 circularity=0.60-1.00 show=Masks exclude in_situ");