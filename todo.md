# boids
detect neighbouring boids.
make an editor for this to make sure it works.
select a boid and highlight its neighbours


shader storage buffers
convert opengl stuff to dsa

deleting lights and game objects from editor menu
use zon instead of json

# voxel engine
-- rendering blocks
-- block types
-- basic grid

- FIX SHADER HOT RELOADING

instancing? would have to:
    - send model matrices
    - send color data
    - send texture data

# HAVE TO DO THIS

Culled mesher. look for adjacent voxels
and don't draw a side if there is a voxel neighbouring it on that side
use gl.CullFace?
don't draw voxels you can't see
how would colors work?
how would normals / uvs work

chunks
greedy mesher
wireframe shader for voxels

removing and placing blocks
frustum culling
shadows
lighting
procedural terrain generation
procedural vegetation / water
trees
light editor - help move lights. see where they are facing, etc
collisions
voxel textures
particle systems
water
clouds
day night cycle
terrain editing

caves
physics
marching cubes
volumetrics
