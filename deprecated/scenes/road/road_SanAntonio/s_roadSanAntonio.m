% Examining DJC's roads
%
%

%% Start up ISET and check that docker is configured 
ieInit;
if ~piDockerExists, piDockerConfig; end

%%
% This is a huge scene.  Not just a road, but tons of other stuff.
% The directory tree is very deep.
pbrtDir = fullfile(iaRootPath,'data','scenes','road','road_SanAntonio','road_SanAntonio');
exist(pbrtDir,'dir')

pbrtScene = fullfile(pbrtDir,'road_SanAntonio.pbrt');
exist(pbrtScene,'file')

thisR = piRead(pbrtScene);

%{
% Kind of odd parsing.  There are tons of objects when you use
% thisR.show('objects');
% There is also a point light source.
% piAssetGeometry runs, but there are tons of things.
% It would be nice to just have the road without all the stuff.
% Probably possible.
>> thisR = piRead(pbrtScene);
Read 22 materials and 0 textures.
Start Object processing.
Object 1: Identified 1 assets; parsed up to line 8264
Object 2: Identified 0 assets; parsed up to line 2
Object 3: Identified 0 assets; parsed up to line 2
Finished Object processing.
Attribute processing: Identified 1 assets; parsed up to line 25

thisR.get('camera')

ans = 

  struct with fields:

       type: 'Camera'
    subtype: 'perspective'
        fov: [1×1 struct]
%}

%%  Try it

scene = piWRS(thisR,'remote resources',true);

%{
Status:
     1

Result:
pbrt version 4 (built Jun  1 2023 at 17:41:24)

Copyright (c)1998-2021 Matt Pharr, Wenzel Jakob, and Greg Humphreys.

The source code to pbrt (but *not* the book contents) is covered by the Apache 2.0 License.

See the file LICENSE.txt for the conditions of the license.

[1m[31mError[0m: road_SanAntonio_geometry.pbrt:127:0: light_yellow_off_SignalNode.043.Signals_LightsOff01_Diff.png_Signal.alphamap.Signals_LightsOff01_Diff.png: alpha texture not defined.

[1m[31mError[0m: road_SanAntonio_geometry.pbrt:140:0: light_yellow_on_SignalNode.043.Signals_LightsOn01_Diff.png_Signal.alphamap.Signals_LightsOn01_Diff.png: alpha texture not defined.

[1m[31mError[0m: geometry/road_SanAntonio-70a13016.pbrt:1:0: Eucalyptus_Sm01_Trunk_FoliageNode.113.Leaves_Foliage.alphamap.EucalyptusLeaves_Diff.png: alpha texture not defined.


%}
