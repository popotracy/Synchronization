clear, close all, clc
cd C:\Users\fabie\OneDrive\Documents\eeglab2023.0 % The eeglab toolbox directory must NOT contain spaces
eeglab
addpath('C:\Users\fabie\Universite de Montreal\ProjetMonark\scripts')

EMG_lag = 0.013 ; % lag in secs, to be converted in frames

Trials = {'Fabien_100W_Essai1','Fabien_100W_Essai2','Fabien_100W_Essai3',...
    'Fabien_150W_Essai1','Fabien_150W_Essai2','Fabien_150W_Essai3','Fabien_Baseline'} ;

for iT=1:length(Trials)
    %% EEG
    % load EEG data
    EEG = pop_biosig(['C:\Users\fabie\Universite de Montreal\ProjetMonark\Data\Fabien\' Trials{iT} '.bdf']) ;

    % Keep only EEG data
    EEG = pop_select( EEG, 'chantype',{'EEG'});
    ConversionTable = {...
        'C1','CC1';'C2','CC2';'C3','CC3';'C4','CC4';'C5','CC5';'C6','CC6';'C7','CC7';'C8','CC8';'C9','CC9';'C10','CC10';...
        'C11','CC11';'C12','CC12';'C13','CC13';'C14','CC14';'C15','CC15';'C16','CC16';'C17','CC17';'C18','CC18';'C19','CC19';'C20','CC20';...
        'C21','CC21';'C22','CC22';'C23','CC23';'C24','CC24';'C25','CC25';'C26','CC26';'C27','CC27';'C28','CC28';'C29','CC29';'C30','CC30';...
        'C31','CC31';'C32','CC32'};
    for p=1:length(ConversionTable)
        for q=1:length(EEG.chanlocs)
            if strcmp(ConversionTable{p,1},EEG.chanlocs(q).labels)
                EEG.chanlocs(q).labels = ConversionTable{p,2}  ;
                break
            end
        end
    end

    ConversionTable = {...
        'A1','Cz'; 'A3','CPz';'A10','PO7';'A15','O1';'A19','Pz';'A21','POz';'A23','Oz';'A25','Iz';'A28','O2';...
        'B7','PO8';'B11','P8';'B14','TP8';'B20','C2';'B22','C4';'B24','C6';'B26','T8';'B27','FT8';...
        'CC7','F8';'CC8','AF8' ;'CC16','Fp2';'CC17','Fpz';'CC19','AFz';'CC21','Fz';'CC23','FCz';'CC29','Fp1';'CC30','AF7';...
        'D7','F7' ;'D8','FT7';'D14','C1';'D19','C3';'D21','C5';'D23','T7';'D24','TP7';'D31','P7';...
        } ;
    for p=1:length(ConversionTable)
        for q=1:length(EEG.chanlocs)
            if strcmp(ConversionTable{p,1},EEG.chanlocs(q).labels)
                EEG.chanlocs(q).labels = ConversionTable{p,2}  ;
                break
            end
        end
    end

    % Define electrode location
    EEG = pop_chanedit(EEG,'lookup','C:\Users\fabie\Universite de Montreal\ProjetMonark\scripts\Biosemi_128electrodes_Coordinates_GoodOrientation_GoodNames.ced');

    % keep 1 sec before and 1 sec after the first and last TTL
    retain_data_intervalsEEG = EEG.event(1).latency-EEG.srate : EEG.event(2).latency+EEG.srate ;
    EEG = pop_select(EEG, 'point', retain_data_intervalsEEG);

    %% EMG-Monark-Trigger
    load(['C:\Users\fabie\Universite de Montreal\ProjetMonark\Data\Fabien\' Trials{iT} '.mat'])
    CED_rate = round(1/VM.interval) ;

    EMG_Channels = {'TA','SOL','GM','GL','VM','VL','RF','ST','BF','TFL','GMAX','ES','ES2'} ;
    for iEMG = 1:length(EMG_Channels)
        eval(['EMG(iEMG,:) = ' EMG_Channels{iEMG} '.values ;']) ;
        eval(['EMG_names{iEMG} = ' EMG_Channels{iEMG} '.title ;'])  ;
    end

    Monark_Channels = {'position','torque'} ;
    for iMonark = 1:length(Monark_Channels)
        eval(['Monark(iMonark,:) = ' Monark_Channels{iMonark} '.values ;']) ;
        eval(['Monark_names{iMonark} = ' Monark_Channels{iMonark} '.title ;'])  ;
    end

    Trigger = Trigger.values ;

    % Segment data according to -1sec before the first trigger  (beginning
    % of trial) to +1sec after the second trigger (end of trial)
    Trigger = Trigger>1 ;
    Trigger_frames= [] ;
    for p=2:length(Trigger)
        if (Trigger(p)-Trigger(p-1))==1
            Trigger_frames(end+1) = p ;
        end
    end

    retain_data_intervalsCED = Trigger_frames(1)-CED_rate : Trigger_frames(2)+CED_rate ;
    EMG = EMG(:,retain_data_intervalsCED+round(EMG_lag*CED_rate)) ;
    Monark = Monark(:,retain_data_intervalsCED) ;
    Trigger = double(Trigger)' ; Trigger = Trigger(:,retain_data_intervalsCED) ;

    %% Verif EEG versus CED time duration between triggers
    EEG_time = EEG.pnts/EEG.srate ;
    CED_time= length(retain_data_intervalsCED)/CED_rate ;
    msgbox( { ['Trial : ' Trials{iT}] ;['Duration EEG : ' num2str(EEG_time)];['Duration CED : ' num2str(CED_time)]})

    %% Synchronize all data
    % Interpolate and add EMG data to the EEGlab structure
    EMG_Int = interp1(...
        1:length(retain_data_intervalsCED),EMG',...
        linspace(1,length(retain_data_intervalsCED),EEG.pnts),'spline')' ;
    for iChan = 1:length(EMG_names)
        EEG.chanlocs(EEG.nbchan+iChan).labels = EMG_names{iChan} ;
        EEG.chanlocs(EEG.nbchan+iChan).type = 'EMG' ;
        EEG.chanlocs(EEG.nbchan+iChan).ref = 'none' ;
    end
    EEG.data = [ EEG.data ; EMG_Int ] ;
    EEG.nbchan =  size(EEG.data,1) ;

    % Interpolate and add Monark data to the EEGlab structure
    Monark_Int = interp1(...
        1:length(retain_data_intervalsCED),Monark',...
        linspace(1,length(retain_data_intervalsCED),EEG.pnts),'spline')' ;
    for iChan = 1:length(Monark_names)
        EEG.chanlocs(EEG.nbchan+iChan).labels = Monark_names{iChan} ;
        EEG.chanlocs(EEG.nbchan+iChan).type = 'Bike' ;
        EEG.chanlocs(EEG.nbchan+iChan).ref = 'none' ;
    end
    EEG.data = [ EEG.data ; Monark_Int ] ;
    EEG.nbchan =  size(EEG.data,1) ;

    % Interpolate and add Trigger data to the EEGlab structure
    Trigger_Int = interp1(...
        1:length(retain_data_intervalsCED),Trigger',...
        linspace(1,length(retain_data_intervalsCED),EEG.pnts),'spline') ;

    EEG.chanlocs(EEG.nbchan+1).labels = 'Trigger' ;
    EEG.chanlocs(EEG.nbchan+1).type = 'Trigger' ;
    EEG.chanlocs(EEG.nbchan+1).ref = 'none' ;

    EEG.data = [ EEG.data ; Trigger_Int ] ;
    EEG.nbchan =  size(EEG.data,1) ;

    EEG.data = double(EEG.data) ;

    %% Create events according to the pedalling cycle
    if ~contains(Trials{iT},'Baseline')
        CycleOnset = Detect_Cycles(EEG.data(134,:),CED_rate) ; % Use VM activation to create events
        event_nb = length(EEG.event) ; urevent_nb = length(EEG.urevent) ;
        for p=1:length(CycleOnset)
            EEG.event(event_nb+p).type = 'CycleOnset' ;
            EEG.event(event_nb+p).latency = CycleOnset(p) ;
            EEG.event(event_nb+p).duration = 1 ;
            EEG.event(event_nb+p).urevent = urevent_nb+p  ;
        end
        EEG = pop_editeventvals(EEG,'latency',0) ;
    end

    %% Save the data
    EEG = pop_saveset( EEG, 'filename',[  Trials{iT} '.set'],'filepath','C:\\Users\\fabie\\Universite de Montreal\\ProjetMonark\\Preprocessing\\1_SynchronizedData');
    clear EMG Monark
end

