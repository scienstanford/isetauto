function assetlist = iaAssetListCreate(varargin)
% Create an assetList for objects on flywheel
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
p.addParameter('session','');
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
nassets          = p.Results.nassets;

% return empty if no assets are requested.
if nassets == 0, assetlist=[];return; end

%% Find all the acuisitions
session = st.lookup(sprintf('wandell/Graphics auto v4/assets/%s', sessionname), true);
acqs    = session.acquisitions();

%%
nDatabaseAssets = length(acqs);

if isempty(acquisitionname)
    % No acquisition name. Loop across all of them.

    if ~isempty(nassets)
        % if an asset is used more than once, we create an object instance
        % list. Object instancing saves memory usage and rendering time.
        assetList_select = randi(nDatabaseAssets,nassets,1);
    else
        assetList_select = 1:nDatabaseAssets;
    end
    
    % Assets we want to download
    downloadList = piObjectInstanceCount(assetList_select);
    nDownloads   = numel(downloadList);
    
    for ii = 1:nDownloads
        assetIndex  = downloadList(ii).index;
        acqLabel    = acqs{assetIndex}.label;
        localFolder = fullfile(iaRootPath,'local','AssetLists',acqLabel);
        
        if ~exist(localFolder,'dir')
            mkdir(localFolder)
        end
        
        [thisR, acqId, resourcesName] = piFWAssetCreate(acqs{assetIndex});        
        

        assetlist(ii).name               = acqLabel;
        assetlist(ii).recipe             = thisR;
        assetName                        = getAssetName(thisR);
        assetID = piAssetFind(thisR,'name', assetName);
        assetlist(ii).size               = thisR.assets.Node{assetID}.size;
        
        assetlist(ii).position           = thisR.assets.Node{assetID}.translation;
        assetlist(ii).rotation           = thisR.assets.Node{assetID}.rotation;
        assetlist(ii).fwInfo             = [acqId,' ',resourcesName];
        assetlist(ii).count              = downloadList(ii).count; % how many times this asset are instantiated.
    end
    
    fprintf('%d assets added to the list.\n',nDownloads);
else
    %% We have the name, so find the acquisitions that match the name, and 
    % we can have multiple matched acquisitions.
    thisAcq = stSelect(acqs,'label',acquisitionname);
%     assetlist = zeros(numel(thisAcq),1);
    % Loop across all of them
    assetlist = struct();
    for ii = 1:numel(thisAcq)
        acqLabel = thisAcq{ii}.label;
        localFolder = fullfile(iaRootPath,'local','AssetLists',acqLabel);
        if ~exist(localFolder,'dir')
            mkdir(localFolder)
        end
        [thisR, acqId, resourcesName]   = piFWAssetCreate(thisAcq{ii});        
        
        assetlist(ii).name              = acqLabel;
        assetlist(ii).recipe            = thisR;
        assetName                       = getAssetName(thisR);
        assetlist(ii).size              = thisR.get('assets',assetName,'size');
        assetlist(ii).position          = thisR.get('assets',assetName,'world position');
        assetlist(ii).rotation          = thisR.get('assets',assetName,'world rotationmatrix');
        assetlist(ii).fwInfo            = [acqId,' ',resourcesName];
        assetlist(ii).count             = 1;
    end
    fprintf('%s added to the list.\n',acqLabel);
end
end
function assetName = getAssetName(thisR)
    assetNames = thisR.get('asset names');
    % this may cause problems.
    for ii = 1:numel(assetNames)
        if piContains(assetNames{ii},'_B')
            assetName = assetNames{ii};
            break;
        end
    end
end

