function [] = main()

if isempty(getenv('SCA_SERVICE_DIR'))
    disp('setting SCA_SERVICE_DIR to pwd')
    setenv('SCA_SERVICE_DIR', pwd)
end

disp('loading paths')
%addpath(genpath('/N/u/hayashis/BigRed2/git/encode')) %not used?
addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'))
addpath(genpath('/N/u/hayashis/BigRed2/git/jsonlab'))

% load my own config.json
config = loadjson('config.json');
[ out ] = make_wm_mask(config);

% Save output
% No save out put in this main file the file is saved inside make_wm_mask
