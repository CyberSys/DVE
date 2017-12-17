![servicesbanner](http://yonaka.no/images/DVELogo.png)

## Work in progress

# DVE - Delphi Voxel Engine

**Uses**
* OpenGL 3.1+ through [dglOpenGL](https://github.com/SaschaWillems/dglOpenGL)
* [Neslib.FastMath](https://github.com/neslib/FastMath)
* Temporary?: [nothings stb](https://github.com/noct/stb) through [DelphiStb](https://github.com/neslib/DelphiStb)

**Overview**
* Simple; one unit for OpenGL, one unit for Chunk manager and one unit for the Chunk template
* Barebone starting point for OpenGL Voxel engine for Delphi
* Run on TPanel in VCL during development. Easily deploy as non VCL app.
* [Discord channel](https://discord.gg/hkyceF)

**Features**
* Frustrum culling
* Block-block culling
* Ambient occlusion
* Chunks

# Roadmap

**Done**
* Frustrum-, and blockface culling
* Ambient occlusion
* Autogenerated terrain 

**Todo**
* Define list of TChunk types and their textures externally
* Skybox
* Improve performance: one sided triangles?
* Environment Lighting
* VAO creation in Thread(s)?
* Picking
* Block highlight
* Grids
* GUI or feedback

**Bugs**
~~* Noise not continuous~~

