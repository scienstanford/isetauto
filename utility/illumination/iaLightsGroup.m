function recipeList = iaLightsGroup(thisR, skymap)
% Create recipes that contain specific types of lights, but not others
%
% Brief description:
%   Create multiple recipes with distinct light groups from an
%   original recipe.  Used frequently for driving scenes with multiple
%   types of light sources.
% 
% Inputs:
%   thisR  - render recipe of the scene.
%   skymap - a string used to label a skymap
%
% Ouputs: 
%   recipeList - a cell array of recipes made from only a certain type
%                of light source
%
% Description
%  A driving scene recipe usually contains a large number of different
%  types of lights. It is convenient to separate out the recipe into
%  distinct recipes that contain only one of the different types of
%  lights. These are skymap, headlight, streetlight, or other.
%
%  This function takes one recipe as input and returns a cell array of
%  four recipes, with each one containing only lights of one of the
%  four types. We render each of these, and then we use sceneAdd to
%  create mixtures of the different renderings, effectively
%  controlling the lighting.  The sceneAdd mixing is much faster than
%  re-rendering.
%
% Zhenyi, 2022

% lightNames = thisR.get('lights','namesid'); % long name

%% Initialize the four different types of recipes we will create.
[outputDir,scenename] = fileparts(thisR.get('outputfile'));

recipeSkymap = piRecipeCopy(thisR); SkylightFlag = false;
recipeSkymap.set('outputFile',fullfile(outputDir, [scenename, '_skymap.pbrt']));

recipeHeadLights = piRecipeCopy(thisR); HeadlightFlag = false;
recipeHeadLights.set('outputFile',fullfile(outputDir, [scenename, '_headlights.pbrt']));

recipeStreetLights = piRecipeCopy(thisR); StreetlightFlag = false;
recipeStreetLights.set('outputFile',fullfile(outputDir, [scenename, '_streetlights.pbrt']));

recipeOtherLights = piRecipeCopy(thisR); OtherlightFlag = false;
recipeOtherLights.set('outputFile',fullfile(outputDir, [scenename, '_otherlights.pbrt']));

% These seem unused
%  ss = 1;
%  hh = 1;
%  ee = 1;
%  ll = 1;
%{
for ii =  1:numel(lightNames)
    light = lightNames{ii};
    % keep only skymap
    if ~contains(light, skymap)
        ssCounts{ss} = light;
        try
            recipeSkymap = piAssetDelete(recipeSkymap, light(8:end));
        catch
            recipeSkymap.assets  = recipeSkymap.assets.uniqueNames;
            recipeSkymap = piAssetDelete(recipeSkymap, light(8:end));
        end
        ss = ss+1;
    end
    % keep headlights
    if ~contains(light, {'headlamp','headlight'})
        hhCounts{hh} = light;
        try
            recipeHeadLights = piAssetDelete(recipeHeadLights, light(8:end));
        catch
            recipeHeadLights.assets  = recipeHeadLights.assets.uniqueNames;
            recipeHeadLights = piAssetDelete(recipeHeadLights, light(8:end));
        end
        hh = hh+1;
    end
    % remove all headlights and skymap
    if contains(light, {'headlamp','headlight'}) ||...
            contains(light, skymap) ||...
            contains(light, {'streetlight','streelight'})

        eeCounts{ee} = light;
        try
        recipeOtherLights = piAssetDelete(recipeOtherLights, light(8:end));
        catch
        recipeOtherLights.assets  = recipeOtherLights.assets.uniqueNames;
        recipeOtherLights = piAssetDelete(recipeOtherLights, light(8:end));
        end
        ee = ee+1;
    end 

    if ~contains(light, {'streetlight','streelight'})
        llCounts{ll} = light;
        try
            recipeStreetLights = piAssetDelete(recipeStreetLights, light(8:end));
        catch
            recipeStreetLights.assets  = recipeStreetLights.assets.uniqueNames;
            recipeStreetLights = piAssetDelete(recipeStreetLights, light(8:end));
        end
        ll = ll+1;
    else
        disp(light);
    end
    
end
%}


%% Walk through the nodes, looking for lights.

% For each type of recipe, we keep only the lights of its own type
% (skymap, healight, streetLight, or Other).

nNodes = numel(thisR.assets.Node);
NodeList = thisR.assets.Node;

for nn = nNodes:-1:1
    thisNode =  NodeList{nn};
    if ~ischar(thisNode) && strcmp(thisNode.type,'light')
        % It's a lot.  Delete it from all the recipes that are not of
        % the same type.  
        light = thisNode.name;
        if ~contains(light, skymap) 
            % Not a skymap.  So delete it from this one.
            recipeSkymap.assets = recipeSkymap.assets.chop(nn); 
        else
            SkylightFlag = true;
        end

        if ~contains(light, {'headlight','headlamp'})
            % Not a headlight or headlamp.  Delete from this one.
            recipeHeadLights.assets = recipeHeadLights.assets.chop(nn); 
        else
            HeadlightFlag = true;
        end

        if ~contains(light, 'streetlight')
            % Not a Street light.  Delete from this one.
            recipeStreetLights.assets = recipeStreetLights.assets.chop(nn); 
        else
             StreetlightFlag = true;
        end

        if contains(light, {'headlamp','headlight'}) || ...
                contains(light, skymap) || ...
                contains(light, 'streetlight') 
            % If it is a skymap, headlight, or a streetlight (possibly
            % mis-spelled), delete it from 'Other'.  If it is not one
            % of these, we will leave it.
            recipeOtherLights.assets = recipeOtherLights.assets.chop(nn);
        else
            OtherlightFlag = true;
        end
    end
end

% fprintf('Skylight group remove %d lights. \n', numel(ssCounts));
% fprintf('Headlight group remove %d lights. \n', numel(hhCounts));
% fprintf('Streetlight group remove %d lights. \n', numel(llCounts));
% fprintf('Otherlight group remove %d lights. \n', numel(eeCounts));

%% Create the cell array of recipes to return

recipeSkymap.assets       = recipeSkymap.assets.uniqueNames;
recipeHeadLights.assets   = recipeHeadLights.assets.uniqueNames;
recipeStreetLights.assets = recipeStreetLights.assets.uniqueNames;
recipeOtherLights.assets  = recipeOtherLights.assets.uniqueNames;

if SkylightFlag
    recipeList{1} = recipeSkymap;
else
    disp('No Skylight Found.');
    recipeList{1} = [];
end

if HeadlightFlag
    recipeList{2} = recipeHeadLights;
else
    disp('No Headlight Found.');
    recipeList{2} = [];
end

if StreetlightFlag
    recipeList{3} = recipeStreetLights;
else
    disp('No Streetlight Found.');
    recipeList{3} = [];
end

if OtherlightFlag
    recipeList{4} = recipeOtherLights;
else
    disp('No Otherlight Found.');
    recipeList{4} = [];
end

% Remove empty cells
recipeList = recipeList(~cellfun('isempty',recipeList));

end