%% Synchronization of EEG and EMG

% Load eeglab https://sccn.ucsd.edu/eeglab/download.php

%% EEG data are : \\10.89.24.15\q\Projet_RAC\DATA\RAW\P23\01\EEG\cuedPref.eeg
%% Nexus data are : \\10.89.24.15\q\Projet_RAC\DATA\RAW\P23\01\Nexus\cuedPref.c3d (force platform + sound + trigger)

clear; clc ;
addpath(genpath('C:\Program Files\MATLAB\R2018a\toolbox\matlab\datatypes\@timetable'))
addpath(genpath('\\10.89.24.15\e\Projet_ForceMusculaire\Fabien_ForceMusculaire\functions\btk'))
addpath(genpath('\\10.89.24.15\e\Projet_EEG_Posture\eeglab14_1_2b\functions'))
run \\10.89.24.15\e\Projet_EEG_Posture\eeglab14_1_2b\eeglab


Trigger_number = [...
    1 1 3 3 5 5 7 7 9 9 ;...
    2 2 4 4 6 6 8 8 10 10] ;

EMG_channels = {...
    'Sensor_1_IM_EMG1','Sensor_2_IM_EMG2','Sensor_3_IM_EMG3','Sensor_4_IM_EMG4','Sensor_5_IM_EMG5','Sensor_6_IM_EMG6','Sensor_7_IM_EMG7','Sensor_8_IM_EMG8','Sensor_9_IM_EMG9'};

ForcePlatform_channels = {} ;

Sound_channel = {} ;


% EEG loading
EEG = pop_biosig(['\\10.89.24.15\j\EEG_Posture\PARTICIPANT\' subject_number{iS} '\' subject_name{iS} '_EEG\' conditions{iC} '.eeg']);

% Change Trigger names
if ~contains(conditions{1,iC},'Assis')
    if length(EEG.event)==3
        if EEG.event(2).latency>150*EEG.srate
            final_event = EEG.event(2).latency ;
            EEG.event(2).latency = final_event-(150*EEG.srate) ;
            EEG.event(3).latency = final_event ;
        else
            starting_event = EEG.event(2).latency ;
            EEG.event(3).latency = starting_event+(150*EEG.srate) ;
        end

    elseif length(EEG.event)==5
        if EEG.event(3).latency >150*(EEG.srate) && EEG.event(4).latency>150*(EEG.srate)
            final_event = EEG.event(2).latency ;
            EEG.event(2).latency = final_event-(150*EEG.srate) ;
            EEG.event(3).latency = final_event ;
        elseif EEG.event(3).latency <150*(EEG.srate) && EEG.event(4).latency < 150*(EEG.srate)
            starting_event = EEG.event(2).latency ;
            EEG.event(3).latency = starting_event + (150*EEG.srate) ;
        else
            EEG.event(3).latency = EEG.event(4).latency ;
        end
        for p=4:5
            EEG.event(p).type = []; EEG.event(p).latency = []; EEG.event(p).duration = []; EEG.event(p).urevent = [];
        end

    elseif length(EEG.event)==7
        if EEG.event(4).latency>150*EEG.srate
            EEG.event(3).latency = EEG.event(4).latency ;
        else
            EEG.event(3).latency = EEG.event(6).latency ;
        end
        for p=4:7
            EEG.event(p).type = []; EEG.event(p).latency = []; EEG.event(p).duration = []; EEG.event(p).urevent = [];
        end

    else
        EEG.event(3).latency = EEG.event(6).latency ;
        for p=4:9
            EEG.event(p).type = []; EEG.event(p).latency = []; EEG.event(p).duration = []; EEG.event(p).urevent = [];
        end
    end
else
    EEG.event(1).duration = 1;
    EEG.event(2).type = 3 ; EEG.event(2).latency = EEG.srate ; EEG.event(2).urevent = 2 ; EEG.event(2).duration = 1;
    EEG.event(3).type = 2 ; EEG.event(3).latency = EEG.event(2).latency+(150*EEG.srate); EEG.event(3).urevent = 3 ; EEG.event(3).duration = 1;
end

EEG.event(2).type = Trigger_number(1,iC) ;
EEG.event(3).type = Trigger_number(2,iC) ;


EEG.urevent = EEG.event ;
EEG.urevent = rmfield(EEG.urevent,'urevent') ;

EEG = pop_epoch( EEG, {  EEG.event(2).type  }, [-0.1  150.1]);


%% VICON
acq = btkReadAcquisition(['\\10.89.24.15\j\EEG_Posture\PARTICIPANT\' subject_number{iS} '\' subject_name{iS} '_Vicon\Test\' conditions{iC} '.c3d']);
EMG = btkGetAnalogs(acq) ;
Data.EMG_FreqSamp = btkGetAnalogFrequency(acq) ;

ForcePlate = [EMG.Force_Fx1 EMG.Force_Fy1 EMG.Force_Fz1 EMG.Moment_Mx1 EMG.Moment_My1 EMG.Moment_Mz1 ] ;

for iM = 1:length(EMG_channels)
    Data.EMG(:,iM) = EMG.(EMG_channels{iM}) ;
end

% Interpolation ForcePlate
vq_FP = interp1(1:length(ForcePlate),ForcePlate,linspace(1,length(ForcePlate),length(ForcePlate)/(Data.EMG_FreqSamp/EEG.srate)),'spline');
vq_FP = vq_FP.';

% Interpolation Data.EMG
vq_EMG = interp1(1:length(Data.EMG),Data.EMG,linspace(1,length(Data.EMG),length(Data.EMG)/(Data.EMG_FreqSamp/EEG.srate)),'spline');
vq_EMG = vq_EMG.';

% Interpolation Force_1
vq_trigger = interp1(1:length(EMG.Force_1),EMG.Force_1,linspace(1,length(EMG.Force_1),length(EMG.Force_1)/(Data.EMG_FreqSamp/EEG.srate)),'spline');

% take data from EMG juste at the trigger frames
trigger_frames = find(vq_trigger>-0.5);
start_trigger_EMG = trigger_frames(1);
stop_trigger_EMG = trigger_frames(length(trigger_frames)-1);


vq_FP = vq_FP(:,start_trigger_EMG-100:length(EEG.data)+(start_trigger_EMG-EEG.event(1).latency));
vq_EMG = vq_EMG(:,start_trigger_EMG-100:length(EEG.data)+(start_trigger_EMG-EEG.event(1).latency));
vq_trigger = vq_trigger(start_trigger_EMG-100:length(EEG.data)+(start_trigger_EMG-EEG.event(1).latency));

trigger_frames_s = find(vq_trigger>-0.5);
start_trigger_EMGs = trigger_frames_s(1);
stop_trigger_EMGs = trigger_frames_s(find(trigger_frames_s>150*EEG.srate,1));

verif_sync(1,1) = EEG.event(1).latency ;
verif_sync(2,1) = EEG.event(2).latency ;
verif_sync(1,2) = start_trigger_EMGs ;
verif_sync(2,2) = stop_trigger_EMGs ;

syncdata = [EEG.data; vq_EMG; vq_FP; vq_trigger];
EEG.data = syncdata ;
EEG.nbchan =  size(EEG.data,1) ;


EEG.chanlocs(65,1).labels = 'Sensor_1_IM_EMG1'; EEG.chanlocs(65,1).type = 'EMG'; EEG.chanlocs(65,1).ref = 'none';
EEG.chanlocs(66,1).labels = 'Sensor_2_IM_EMG2'; EEG.chanlocs(66,1).type = 'EMG'; EEG.chanlocs(66,1).ref = 'none';
EEG.chanlocs(67,1).labels = 'Sensor_3_IM_EMG3'; EEG.chanlocs(67,1).type = 'EMG'; EEG.chanlocs(67,1).ref = 'none';
EEG.chanlocs(68,1).labels = 'Sensor_4_IM_EMG4'; EEG.chanlocs(68,1).type = 'EMG'; EEG.chanlocs(68,1).ref = 'none';
EEG.chanlocs(69,1).labels = 'Sensor_5_IM_EMG5'; EEG.chanlocs(69,1).type = 'EMG'; EEG.chanlocs(69,1).ref = 'none';
EEG.chanlocs(70,1).labels = 'Sensor_6_IM_EMG6'; EEG.chanlocs(70,1).type = 'EMG'; EEG.chanlocs(70,1).ref = 'none';
EEG.chanlocs(71,1).labels = 'Sensor_7_IM_EMG7'; EEG.chanlocs(71,1).type = 'EMG'; EEG.chanlocs(71,1).ref = 'none';
EEG.chanlocs(72,1).labels = 'Sensor_8_IM_EMG8'; EEG.chanlocs(72,1).type = 'EMG'; EEG.chanlocs(72,1).ref = 'none';
EEG.chanlocs(73,1).labels = 'Sensor_9_IM_EMG9'; EEG.chanlocs(73,1).type = 'EMG'; EEG.chanlocs(73,1).ref = 'none';
EEG.chanlocs(74,1).labels = 'Force_Fx1'; EEG.chanlocs(74,1).type = 'Plateforme de Force';EEG.chanlocs(74,1).ref = 'none';
EEG.chanlocs(75,1).labels = 'Force_Fy1'; EEG.chanlocs(75,1).type = 'Plateforme de Force';EEG.chanlocs(75,1).ref = 'none';
EEG.chanlocs(76,1).labels = 'Force_Fz1'; EEG.chanlocs(76,1).type = 'Plateforme de Force';EEG.chanlocs(76,1).ref = 'none';
EEG.chanlocs(77,1).labels = 'Moment_Mx1'; EEG.chanlocs(77,1).type = 'Plateforme de Force';EEG.chanlocs(77,1).ref = 'none';
EEG.chanlocs(78,1).labels = 'Moment_My1'; EEG.chanlocs(78,1).type = 'Plateforme de Force';EEG.chanlocs(78,1).ref = 'none';
EEG.chanlocs(79,1).labels = 'Moment_Mz1'; EEG.chanlocs(79,1).type = 'Plateforme de Force';EEG.chanlocs(79,1).ref = 'none';
EEG.chanlocs(80,1).labels = 'Force_1'; EEG.chanlocs(80,1).type = 'trigger';EEG.chanlocs(80,1).ref = 'none';


eeglab redraw
EEG = pop_saveset(EEG, [subject_number{iS},'_',conditions{iC},'_sync.set'],['\\10.89.24.15\e\Projet_EEG_Posture\ICA_data\Sync\New\',subject_number{iS}]);
%            clearvars -except subject_number subject_name conditions EMG_channels Trigger_number iS


