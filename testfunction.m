%% explain 
%
% explain things
%

function [arg1, arg2]=testfunction(var)

     if nargout >1
         arg1=var*2;
         arg2=var*4;
     else 
        arg1=var*3;
     end
    
    
end

%% 
Conditions={'cuedPref' 'cuedFast'};
cfg.dataset   = 'P2_01_cuedPref_sync.set';  % Run the dataset in the syncfolder
cfg.TaskName        =  cfg.dataset;
strstart=strfind(cfg.dataset, Conditions{1});
strend=strstart+length(Conditions{1})-1;
cfg.dataset(strstart:strend);

%%
path='/Users/tracy/Desktop/UdeM/BIDS/P2_syncdata (18-Oct-2023)'
EEGfilenames={dir([path '*.set']).name};
[~, Conditionname, ~]=fileparts(EEGfilenames);
Conditionname=cellstr(Conditionname)

dir('*.set').name
dir([Rawdatapath(k).EEG '*.vhdr'])