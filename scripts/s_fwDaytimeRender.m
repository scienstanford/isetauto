
ieInit;
piDockerConfig;
%%
rootDir = '/Users/zhenyi/Desktop/DaytimeDrivingAssets';
sceneName = 'city4_14_51_v5.0_f19.12front_o270.00_2019626174221';
inFile = fullfile(rootDir,sceneName,[sceneName,'.pbrt']);
outFile = fullfile(rootDir,'daytimeScene',[sceneName,'.pbrt']);
outFile = piPBRTUpdateV4(inFile,outFile);
%%
v4File = fullfile(rootDir,'daytimeScene/v4',[sceneName,'.pbrt']);

thisR = piRead('/Users/zhenyi/Desktop/DaytimeDrivingAssets/daytimeScene/v4/city4_14:51_v5.0_f19.12front_o270.00_2019626174221.pbrt');
% thisR = piRecipeUpdate(thisR);
%%
outputFile = fullfile(piRootPath, 'local','Dayscene_test','test.pbrt');
thisR.set('output file',outputFile);
thisR.set('render type',{'radiance','depth'});
iaAutoMaterialGroupAssign(thisR);
%%
piWrite(thisR);   

scene = piRender(thisR,'isetdocker',isetdocker);

ip = piRadiance2RGB(scene);ipWindow(ip)