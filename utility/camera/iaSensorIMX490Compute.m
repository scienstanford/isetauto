function lrgb = iaSensorIMX490Compute(radiance,varargin)
% Deprecated:  Use imx490Compute in ISETCam.
%
% https://thinklucid.com/tech-briefs/sony-imx490-hdr-sensor-and-flicker-mitigation/
%
% Synopsis
%  lrgb = iaSensorIMX490Compute(radiance,varargin)
% Brief
%
% Inputs
%
% Optional key/val
%   pixel size
%   film diagonal
%   e time
%   noise flag
%   analog gain
%
%
% Return
%  lrgb - Linear sRGB  (after demosaicking)
%
% See also
%   s_sensorIMX490
%

% Example:
%{
  
%}
%%
varargin = ieParamFormat(varargin);
% Start parsing
p = inputParser;
p.addRequired('radiance',@isstruct);
p.addParameter('pixelsize',2,@isscalar); % um
p.addParameter('filmdiagonal',5,@isscalar); % [mm]
p.addParameter('etime',1/4000,@isscalar); % 
p.addParameter('noiseflag',2,@islogical);
p.addParameter('analoggain',[1/32,1/16,1/2,1],@(x)isequal(numel(x),4));

%%
% Parse the varargin to get the parameters
p.parse(radiance,varargin{:});
radiance     = p.Results.radiance;
pixelSize    = p.Results.pixelsize;
exposureTime = p.Results.etime;
noiseFlag    = p.Results.noiseflag;
analog_gain  = p.Results.analoggain;

if strcmp(radiance.type,'scene')
    oi = piOICreate(radiance.data.photons);
elseif ~strcmp(radiance.type,'opticalimage')
    error('Input should be a scene or optical image');
else
    oi = radiance;
end
if isempty(pixelSize)
    pixelSize = oiGet(oi,'width spatial resolution','microns');
end

oiSize = oiGet(oi,'size');
colorFilterFile = fullfile(isetRootPath,'data/sensor/colorfilters/auto/ar0132atRGB.mat');
%% Create multiple image sensors
%
% Each sensor has different size and gain to match the four elements
% of the imx490.  Large/small pixel and high/low gain.

% Large pixel High Gain
lpixel_hgain = sensorIMX490(...
    'pixelsize', 3*pixelSize*1e-6, ...
    'quantization', '12 bit',...
    'qefilename',colorFilterFile, ...
    'wellcapacity',120000,'fillfactor',1,'isospeed',55,'exposuretime',exposureTime, ...
    'rowcol',ceil([oiSize(1) oiSize(2)]/3));

% Large pixel Ligh Gain
lpixel_lgain = sensorIMX490('pixelsize', 3*pixelSize*1e-6, ...
    'quantization', '12 bit',...
    'qefilename',colorFilterFile, ...
    'wellcapacity',120000,'fillfactor',1,'isospeed',55,'exposuretime',exposureTime, ...
    'rowcol',ceil([oiSize(1) oiSize(2)]/3));

% Small pixel High Gain
spixel_hgain = sensorIMX490('pixelsize', pixelSize*1e-6, ...
    'quantization', '12 bit',...
    'qefilename',colorFilterFile, ...
    'wellcapacity',60000,'fillfactor',1,'isospeed',55,'exposuretime',exposureTime, ...
    'rowcol',[oiSize(1) oiSize(2)]);

% Small pixel Ligh Gain
spixel_lgain = sensorIMX490('pixelsize', pixelSize*1e-6, ...
    'quantization', '12 bit',...
    'qefilename',colorFilterFile, ...
    'wellcapacity',60000,'fillfactor',1,'isospeed',55,'exposuretime',exposureTime, ...
    'rowcol',[oiSize(1) oiSize(2)]);

% Set the noise flag
lpixel_hgain = sensorSet(lpixel_hgain,'noise flag', noiseFlag);
lpixel_lgain = sensorSet(lpixel_lgain,'noise flag', noiseFlag);
spixel_hgain = sensorSet(spixel_hgain,'noise flag', noiseFlag);
spixel_lgain = sensorSet(spixel_lgain,'noise flag', noiseFlag);

%% Determine the gain by using scene illuminance, 
%{
illum = oiGet(oi,'illuminance');
illum = illum^2;
illumRange = linspace(1,max2(illum),5);
for ii = 1:4
    mask = ((illum>illumRange(ii) & illum<illumRange(ii+1)));
    oiM{ii} = oiExtractMask(oi,mask);
end
autoET(1) = autoExposure(oiM{1},lpixel_hgain, 0.95, 'mean');
autoET(2) = autoExposure(oiM{2},lpixel_lgain, 0.95, 'mean');
autoET(3) = autoExposure(oiM{3},spixel_hgain, 0.95, 'mean');
autoET(4) = autoExposure(oiM{4},spixel_lgain, 0.95, 'mean');
%}
%% Analog gains
lpixel_hgain = sensorSet(lpixel_hgain,'analog gain', analog_gain(1));
lpixel_lgain = sensorSet(lpixel_lgain,'analog gain', analog_gain(2));
spixel_hgain = sensorSet(spixel_hgain,'analog gain', analog_gain(3));
spixel_lgain = sensorSet(spixel_lgain,'analog gain', analog_gain(4));

%% Compute

sen_lpixel_hgain = sensorCompute(lpixel_hgain,oi);
sen_lpixel_lgain = sensorCompute(lpixel_lgain,oi);
sen_spixel_hgain = sensorCompute(spixel_hgain,oi);
sen_spixel_lgain = sensorCompute(spixel_lgain,oi);

%% Downsample the small pixel sensor to match the large one.
%
% This is a little strange because the FOV of the small sensor is
% different from the large one (they have the same number of
% rows/cols).  So maybe we need to adjust the rows/cols of the small
% sensor x 3 to match the FOV?


sSize = sensorGet(sen_spixel_lgain, 'size');
[X,  Y]  = meshgrid(1:sSize(2), 1:sSize(1));
[Xq, Yq] = meshgrid(1:3:sSize(2), 1:3:sSize(1));

sub_volts_1 = interp2(X,Y, sen_spixel_hgain.data.volts, Xq, Yq,"linear");
sub_dvs_1   = interp2(X,Y, sen_spixel_hgain.data.dv, Xq, Yq,"linear");

sen_spixel_hgain = sensorSet(sen_spixel_hgain, 'volts', sub_volts_1);
sen_spixel_hgain = sensorSet(sen_spixel_hgain, 'dv', sub_dvs_1);

sub_volts_2 = interp2(X,Y, sen_spixel_lgain.data.volts, Xq, Yq,"linear");
sub_dvs_2   = interp2(X,Y, sen_spixel_lgain.data.dv, Xq, Yq,"linear");

sen_spixel_lgain = sensorSet(sen_spixel_lgain, 'volts', sub_volts_2);
sen_spixel_lgain = sensorSet(sen_spixel_lgain, 'dv', sub_dvs_2);

%% Combine sensor data with different sensors scaled by pixel sizes and gains.

combined_sensor = sen_spixel_lgain.data.volts*3^2/(analog_gain(1)) + ...
    sen_spixel_hgain.data.volts*3^2/(analog_gain(1)/analog_gain(3)) + ...
    sen_lpixel_lgain.data.volts/(analog_gain(1)/analog_gain(2)) + ...
    sen_lpixel_hgain.data.volts;

% Quantize the combined sensor data 
combined_input = 2^24*combined_sensor/max(combined_sensor(:));

rgb_comb = demosaic(uint32(combined_input),'rggb');

lrgb = double(rgb_comb)/max2(double(rgb_comb(:)));

%%
%{
lrgb = double(lrgb)/max2(double(lrgb(:)));
cfa_matrix = sensorGet(sen_spixel_hgain,'sensorqe');
wave = sensorGet(sen_spixel_hgain,'wave');
% energy = rgb_comb .* cfa_matrix';
[r, c, w] = size(lrgb);
% % Reshape the image data into a (r * c) x w format (XW)
im = RGB2XWFormat(lrgb);
imT = im /cfa_matrix;
dataXYZ = ieXYZFromEnergy(imT,wave);
sensorXYZ = XW2RGBFormat(dataXYZ, r, c);
rchannel = double(sensorXYZ(:,:,2));
rchannel = rchannel/max2(rchannel);
figure;plot(1:c,rchannel(ceil(c/2),:),"LineWidth",1.5,"Color","r"); hold on

illum = oiGet(oi,'illuminance');
illum = imresize(illum,[r, c],'Antialiasing',false);
illum_norm = illum/max2(illum);
plot(1:c,illum_norm(ceil(c/2),:),"LineWidth",1.5,"Color","b");
legend('Sensor','Radiance');
%}
end

%{
%%
function oiM = oiExtractMask(oi,mask)
% Extract only the pixels from the mask
%
% Mask is binary.
%
oiM = oi;
photons = oi.data.photons;

for ii = 1: size(photons,3)
    photons(:,:,ii) = photons(:,:,ii).*mask;
end
oiM = oiSet(oiM, 'photons',photons);
end
%}


% Merge this into sensorCreate.
% Or maybe it should just be external to sensorCreate in the sensor
% directory.
function sensor = sensorIMX490(varargin)
% Create the sensor structure for the IMX363
%
% Synopsis
%    sensor = sensorIMX363(varargin);
%
% Brief description
%    Creates the default IMX363 sensor model
%
% Inputs
%   N/A
%
% Optional Key/val pairs
%
% Return
%   sensor - struct with the IMX363 model parameters
%
% Examples:  ieExamplesPrint('sensorIMX363');
%
% See also
%  sensorCreate
%
% TODO:
%   We need to make this one the one inside of sensorCreate
% Examples:
%{
 % The defaults and some plots
 sensor = sensorCreate('IMX363');
 sensorPlot(sensor,'spectral qe');
 sensorPlot(sensor,'cfa block');
 sensorPlot(sensor,'pixel snr');
%}
%{
 % Adjust a parameter
 sensor = sensorCreate('IMX363',[],'row col',[256 384]);
 sensorPlot(sensor,'cfa full');
%}

%% Parse parameters

% Building up the input parser will let you do more experiments with the
% sensor.

% This removes spaces and lowers all the letters so you don't have to
% remember the syntax when you call the argument
varargin = ieParamFormat(varargin);

% Start parsing
p = inputParser;

% Set the default values here
p.addParameter('rowcol',[3024 4032],@isvector);
p.addParameter('pixelsize',1.4 *1e-6,@isnumeric);
p.addParameter('analoggain',1.4 *1e-6,@isnumeric);
p.addParameter('isospeed',270,@isnumeric);
p.addParameter('isounitygain', 55, @isnumeric);
p.addParameter('quantization','10 bit',@(x)(ismember(x,{'12 bit','10 bit','8 bit','analog'})));
p.addParameter('dsnu',0,@isnumeric); % 0.0726
p.addParameter('prnu',0.7,@isnumeric);
p.addParameter('fillfactor',1,@isnumeric);
p.addParameter('darkvoltage',0,@isnumeric);
p.addParameter('dn2volts',0.25 * 1e-3,@isnumeric);
p.addParameter('digitalblacklevel', 0, @isnumeric);
p.addParameter('digitalwhitelevel', 4096, @isnumeric);
p.addParameter('wellcapacity',6000,@isnumeric);
p.addParameter('exposuretime',1/60,@isnumeric);
p.addParameter('wave',390:10:710,@isnumeric);
p.addParameter('readnoise',1,@isnumeric);
p.addParameter('qefilename', fullfile(isetRootPath,'data','sensor','qe_IMX363_public.mat'), @isfile);
p.addParameter('irfilename', fullfile(isetRootPath,'data','sensor/irfilters','infrared.mat'), @isfile);
p.addParameter('nbits', 10, @isnumeric);

% Parse the varargin to get the parameters
p.parse(varargin{:});

rows = p.Results.rowcol(1);             % Number of row samples
cols = p.Results.rowcol(2);             % Number of col samples
pixelsize    = p.Results.pixelsize;     % Meters
isoSpeed     = p.Results.isospeed;      % ISOSpeed, whatever that is
isoUnityGain = p.Results.isounitygain;  % ISO speed equivalent to analog gain of 1x, for Pixel 4: ISO55
quantization = p.Results.quantization;  % quantization method - could be 'analog' or '10 bit' or others
wavelengths  = p.Results.wave;          % Wavelength samples (nm)
dsnu         = p.Results.dsnu;          % Dark signal nonuniformity
fillfactor   = p.Results.fillfactor;    % A fraction of the pixel area
darkvoltage  = p.Results.darkvoltage;   % Volts/sec
dn2volts     = p.Results.dn2volts;        % volt per DN
blacklevel   = p.Results.digitalblacklevel; % black level offset in DN
whitelevel   = p.Results.digitalwhitelevel; % white level in DN
wellcapacity = p.Results.wellcapacity;  % Electrons
exposuretime = p.Results.exposuretime;  % in seconds
prnu         = p.Results.prnu;          % Photoresponse nonuniformity
readnoise    = p.Results.readnoise;     % Read noise in electrons
qefilename   = p.Results.qefilename;    % QE curve file name
irfilename   = p.Results.irfilename;    % IR cut filter file name
nbits        = p.Results.nbits; % needs to be set for bracketing to work

%% Initialize the sensor object

sensor = sensorCreate('bayer-rggb');

%% Pixel properties
voltageSwing   = whitelevel * dn2volts;
conversiongain = voltageSwing/wellcapacity; % V/e-

% set the pixel properties
sensor = sensorSet(sensor,'pixel size same fill factor',[pixelsize pixelsize]);
sensor = sensorSet(sensor,'pixel conversion gain', conversiongain);
sensor = sensorSet(sensor,'pixel voltage swing', voltageSwing);
sensor = sensorSet(sensor,'pixel dark voltage', darkvoltage) ;
sensor = sensorSet(sensor,'pixel read noise electrons', readnoise);

% Gain and offset - Principles
%
% In ISETCam we use this formula to incorporate channel gain and offset
%
%         (volts + offset)/gain
%
% Higher ISOspeed requires a bigger multiplier, so we use a formulat like
% this to convert speed to gain.  We should probably make 55 a parameter of
% the system in the inputs, defaulting to 55.
analogGain     = isoUnityGain/isoSpeed; % For Pixel 4, ISO55 = gain of 1

% A second goal is that the offset in digital counts is intended to be a
% fixed level, no matter what the gain might be.  To achieve that we need
% to multiply the 64*one_lsb by the analogGain
%
analogOffset   = (blacklevel * dn2volts) * analogGain; % sensor black level, in volts

% The result is that the output volts are
%
%    outputV = (inputV + analogOffset)/analogGain
%    outputV = inputV*ISOSpeed/55 + analogOffset/analogGain
%    outputV = inputV*ISOSpeed/55 + 64*dn2volts
%
% Since the ADC always operates linearly on the voltage, and the step size
% is one_lsb, the black level for the outputV is always 64.  The gain on
% the input signal is (ISOSpeed/55)
%
%
%% Set sensor properties
%sensor = sensorSet(sensor,'auto exposure',true);
sensor = sensorSet(sensor,'rows',rows);
sensor = sensorSet(sensor,'cols',cols);
sensor = sensorSet(sensor,'dsnu level',dsnu);
sensor = sensorSet(sensor,'prnu level',prnu);
sensor = sensorSet(sensor,'analog Gain',analogGain);
sensor = sensorSet(sensor,'analog Offset',analogOffset);
sensor = sensorSet(sensor,'exp time',exposuretime);
sensor = sensorSet(sensor,'quantization method', quantization);
sensor = sensorSet(sensor,'wave', wavelengths);

% Adjust the pixel fill factor
sensor = pixelCenterFillPD(sensor,fillfactor);

% import QE curve
[data,filterNames] = ieReadColorFilter(wavelengths,qefilename);
sensor = sensorSet(sensor,'filter spectra',data);
sensor = sensorSet(sensor,'filter names',filterNames);
sensor = sensorSet(sensor,'Name','IMX363');

% import IR cut filter
sensor = sensorReadFilter('infrared', sensor, irfilename);

end
