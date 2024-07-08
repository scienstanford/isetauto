function recipe = iaQualitySet(recipe, varargin)
% Allow quick rendering quality presets

varargin =ieParamFormat(varargin);
p = inputParser;

p.addParameter('preset', '');
p.parse(varargin{:})

if ~isempty(p.Results.preset)
    % Set the render quality parameters
    switch p.Results.preset
        case 'dirty'
            recipe.set('film resolution',[640 360]); % Divide by 4 for speed
            recipe.set('pixel samples',64);            % power of 4
            recipe.set('max depth',3);                  % Number of bounces
            recipe.set('sampler subtype','pmj02bn');
        case 'quick'
            recipe.set('film resolution',[1920 1080]/2); % Divide by 4 for speed
            recipe.set('pixel samples',256);            % 256 for power of 4
            recipe.set('max depth',3);                  % Number of bounces
            recipe.set('sampler subtype','pmj02bn');
        case 'quick-rays'
            recipe.set('film resolution',[1920 1080]/2); % Divide by 4 for speed
            recipe.set('pixel samples',512);            % 256 for speed
            recipe.set('max depth',4);                  % Number of bounces
            recipe.set('sampler subtype','pmj02bn');
        case 'HD'
            recipe.set('film resolution',[1920 1080]);
            recipe.set('pixel samples',1024);
            recipe.set('max depth',5);                  % Number of bounces
            recipe.set('sampler subtype','pmj02bn');
        case 'paper'
            % For publication 1080p by as many as 4096 rays per pixel are used
            recipe.set('film resolution',[1920 1080]);
            recipe.set('pixel samples',4096);
            recipe.set('max depth',6);                  % Number of bounces
            recipe.set('sampler subtype','pmj02bn');
    end
end