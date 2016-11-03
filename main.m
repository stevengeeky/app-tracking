function [] = main()

if isempty(getenv('SCA_SERVICE_DIR'))
    disp('setting SCA_SERVICE_DIR to pwd')
    setenv('SCA_SERVICE_DIR', pwd)
end

disp('loading paths')
addpath(genpath('/N/u/hayashis/BigRed2/git/encode'))
addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'))
addpath(genpath('/N/u/hayashis/BigRed2/git/jsonlab'))

%addpath(genpath('/N/u/hayashis/BigRed2/git/mba')) %not used by life?
%addpath(genpath(getenv('SCA_SERVICE_DIR'))) %load life scripts and all

% load my own config.json
config = loadjson('config.json');
[ out ] = make_wm_mask(config);

% Save output
% No save out put in this main file the file is saved inside make_wm_mask
