clear; clc ;
%% Add path (eeg & btk toolbox)

addpath(genpath('\\10.89.24.15\e\Projet_ForceMusculaire\Fabien_ForceMusculaire\functions\btk'))
addpath(genpath('\\10.89.24.15\e\Projet_EEG_Posture\eeglab14_1_2b\functions'))

eeglab_path = fileparts(which('eeglab.m'));
addpath(eeglab_path);
eeglab;

%% Using EEGLab to import data ()
% Load EEG ()
EEG=pop_loadbv('/Users/tracy/Desktop/UdeM/Data_syn/',Subject_number{iS} ,'/', Subject_name,'/','cuedPref.vhdr'); % manually select .vhdr file in pop-up windows

%% Load .mat file(temporarily)
load('Variable.mat'); % comment this (debug mode)


 
% Please indicate the selected variable name in the following:
EEG_trigger='S 13'; 

% Time-series locked
Triggers_EEG = find(cellfun(@(x) isequal(x, EEG_trigger), {EEG.event.type})); % 
Trigger_start=min([EEG.event(Triggers_EEG(1)).latency]);
Trigger_end=max([EEG.event(Triggers_EEG(length(Triggers_EEG)-1)).latency]);
Sampnb_EEG=Trigger_end-Trigger_start;
EEG_rate=EEG.srate;

EEG = pop_select( EEG, 'point',[Trigger_start:Trigger_end-1] );


%% Vicon 
btkGetVersion
acq = btkReadAcquisition('cuedPref.c3d');
EMG = btkGetAnalogs(acq) ;
Vicon_rate = btkGetAnalogFrequency(acq) ;

%% Select Vicon channels

% Please indicate the EEG channel name in the {}.
Chaninfo_FP=fieldnames(EMG); Chaninfo_FP=Chaninfo_FP(1:12);
Chaninfo_Rhythm = {'Force_1'}
Chaninfo_Vicon_trigger = {'Synchronization_1'};
Chaninfo_EMG = {''};
Chaninfo_Vicon=[Chaninfo_FP; Chaninfo_Rhythm;Chaninfo_Vicon_trigger]
%%
% Time-series locked
value=max(EMG.(Chaninfo_Vicon_trigger{1}))
Triggers_vicon=find(EMG.(Chaninfo_Vicon_trigger{1})==value)
Trigger_start=Triggers_vicon(1)
Trigger_end=Triggers_vicon(length(Triggers_vicon)-1) % select the one before the last
Sampnb_vicon=Trigger_end-Trigger_start

% FP
Data_FP=[];
for i=1:length(Chaninfo_FP);
    Data_FP(:,i)=EMG.(Chaninfo_FP{i})(Trigger_start:Trigger_end,:) ; % transpose the matrix
end

% Sound
Data_Rhythm=[];
for i=1:length(Chaninfo_Rhythm)
    Data_Rhythm(:,i) = EMG.(Chaninfo_Rhythm{i})(Trigger_start:Trigger_end,:);
end

% Vicon_trigger
Data_Vicon_stim=[];
for i=1:length(Chaninfo_Vicon_trigger)
    Data_Vicon_stim(:,i) = EMG.(Chaninfo_Vicon_trigger{i})(Trigger_start:Trigger_end,:);
end

% % EMG (n/a)
% DataEMG=[];
% for i=1:length(Chaninfo_EMG)
%     DataEMG(:,i) = EMG.(Chaninfo_EMG{i})(Stim1:Stim2,:);
% end


%% Resample:


vq_FP = interp1(1:length(Data_FP),Data_FP,linspace(1,length(Data_FP),length(EEG.data)),'spline');
vq_FP = vq_FP'

vq_Rhythm = interp1(1:length(Data_Rhythm),Data_Rhythm,linspace(1,length(Data_Rhythm),length(EEG.data)),'spline');
if size(vq_Rhythm)~=size(vq_FP(1,:)), vq_Rhythm = vq_Rhythm'; end

vq_Vicon_stim = interp1(1:length(Data_Vicon_stim),Data_Vicon_stim,linspace(1,length(Data_Vicon_stim),length(EEG.data)),'spline');
if size(vq_Vicon_stim)~=size(vq_FP(1,:)), vq_Vicon_stim = vq_Vicon_stim'; end

syncdata = [EEG.data; vq_FP;vq_Rhythm;vq_Vicon_stim];

save('syndata.mat'); % comment this (debug mode)

for i=1:length(Chaninfo_Vicon)
    EEG.chanlocs(i+EEG.nbchan).labels = Chaninfo_Vicon{i}; 
    EEG.chanlocs(i+EEG.nbchan).type = 'Plateforme de Force'; EEG.chanlocs(i).ref = 'none';
end
EEG.chanlocs(size(EEG.data,1) ).type='trigger';
EEG.data = syncdata ;
EEG.nbchan =  size(EEG.data,1) ;


%%
eeglab redraw
EEG = pop_saveset(EEG, ['Tracy_test_sync.set'],[cd]);


