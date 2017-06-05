function tck2mat()
disp('loading paths')
addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'))
in_fname  = {'output.DT_STREAM.tck','output.SD_STREAM.tck','output.SD_PROB.tck'};
out_fname = {'output.DT_STREAM.mat','output.SD_STREAM.mat','output.SD_PROB.mat'};

parfor ii  = 1:length(in_fname)
fg         = fgRead(in_fname{ii});
fgFileName = out_fname{ii};
fgWrite(fg,fgFileName);
end
