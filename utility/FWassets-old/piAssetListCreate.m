function assetlist = piAssetListCreate(varargin)
% Create an assetList for stationary objects on flywheel
%
% Syntax:
%
% 
% Input:
%  N/A
% Key/val variables
%   session:    session name on flywheel;
%   acquisition: acquisition label on flywheel
%   scitran:  
%
% Output:
%   assetList: Assigned assets libList;
%
%
% Zhenyi updated 2021
%
% See also

%%
p = inputParser;
p.addRequired('session','');
p.addParameter('acquisition','');
p.addParameter('nassets',[]);
p.addParameter('scitran',[]);
p.parse(varargin{:});

st = p.Results.scitran;

if isempty(st)
    st = scitran('stanfordlabs');
end

sessionname      = p.Results.session;
acquisitionname  = p.Results.acquisition;
nassets  = p.Results.nassets;

%% Find all the acuisitions
session = st.lookup(sprintf('wandell/Graphics auto/assets/%s',sessionname),'full');
acqs    = session.acquisitions();

%%
nDatabaseAssets = length(acqs);
if isempty(acquisitionname)
    %% No acquisition name. Loop across all of them.

    if ~isempty(nassets)
        assetList_select = randi(nDatabaseAssets,nassets,1);
    else
        assetList_select = 1:nDatabaseAssets;
    end
    
    % Assets we want to download
    downloadList = piObjectInstanceCount(assetList_select);
    nDownloads = numel(downloadList);
    assetlist = cell(nDownloads,1);
    
    for ii = 1:nDownloads
        assetIndex = downloadList(ii).index;
        acqLabel = acqs{assetIndex}.label;
        localFolder = fullfile(piRootPath,'local','AssetLists',acqLabel);
        if ~exist(localFolder,'dir')
            mkdir(localFolder)
        end
        
        [thisR, acqId, resourcesName] = piFWAssetCreate(acqs{assetIndex});        
        

        assetlist(ii).name               = acqLabel;
        assetlist(ii).materials.list     = thisR.materials.list;
        assetlist(ii).materials.txtLines = thisR.materials.txtLines;
        assetlist(ii).geometry           = thisR.assets;
        assetlist(ii).geometryPath       = fullfile(localFolder,'scene','PBRT','pbrt-geometry');
        assetName                        = getAssetName(thisR, acqLabel);
        assetlist(ii).size               = thisR.get('assets',assetName,'size');
        assetlist(ii).position           = thisR.get('assets',assetName,'world position');
        assetlist(ii).rotation           = thisR.get('assets',assetName,'world rotationmatrix');
        assetlist(ii).fwInfo             = [acqId,' ',resourcesName];
        assetlist{ii}.count              = downloadList(ii).count;
    end
    
    fprintf('%d files added to the asset list.\n',nDatabaseAssets);
else
    %% We have the name, so find the acquisitions that match the name, and 
    % we can have multiple matched acquisitions.
    thisAcq = stSelect(acqs,'label',acquisitionname);

    assetlist = cell(numel(thisAcq),1);
    % Loop across all of them
    for ii = 1:numel(thisAcq)
        acqLabel = thisAcq{ii}.label;
        localFolder = fullfile(piRootPath,'local','AssetLists',acqLabel);
        if ~exist(localFolder,'dir')
            mkdir(localFolder)
        end
        [thisR, acqId, resourcesName]   = piFWAssetCreate(thisAcq{ii});        
        
        assetlist(ii).name = acqLabel;
        assetlist(ii).material.list     = thisR.materials.list;
        assetlist(ii).material.txtLines = thisR.materials.txtLines;
        assetlist(ii).geometry          = thisR.assets;
        assetlist(ii).geometryPath      = fullfile(localFolder,'scene','PBRT','pbrt-geometry');
        assetName                       = getAssetName(thisR, acqLabel);
        assetlist(ii).size              = thisR.get('assets',assetName,'size');
        assetlist(ii).position          = thisR.get('assets',assetName,'world position');
        assetlist(ii).rotation          = thisR.get('assets',assetName,'world rotationmatrix');
        assetlist(ii).fwInfo            = [acqId,' ',resourcesName];
    end
    fprintf('%s added to the list.\n',acqLabel);
end
end
function assetName = getAssetName(thisR, acqLabel)
    assetNames = thisR.get('asset names');
    % this may cause problems.
    for ii = 1:numel(assetNames)
        if piContains(assetNames{ii},'_B') &&...
                piContains(assetNames{ii},acqLabel)
            
            assetName = assetNames{ii};
            break;
        end
    end
end

