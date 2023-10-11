clear; clc ;
%% Add path (eeg & btk toolbox)

addpath(genpath('\\10.89.24.15\e\Projet_ForceMusculaire\Fabien_ForceMusculaire\functions\btk'))
addpath(genpath('\\10.89.24.15\e\Projet_EEG_Posture\eeglab14_1_2b\functions'))
eeglab_path = fileparts(which('eeglab.m'));
addpath(eeglab_path );

%% Retrirve folder information
% Folder structure: 
%
%     Subject-level folder (e.g., P1, P2) 
%               |
%              \|/
%               V
%       Block-level folder (e.g., visit1, visit2 or block1, block2...)
%               |
%              \|/
%               V
%   Condition-level folder (e.g., condition1, condition2 or trial 1, trial2...)
%
% The script will creat a folder in your current folder and save the generated .set files in this folder. 
%
% Please indicate the folder of the participant (Subject-level)
Subjectfolderpath='C:\Users\s\Desktop\Tracy\Data_syn\Synchronization\P2';  
[Parentfolderpath,Subjectfoldername,ext] = fileparts(Subjectfolderpath)

% Recognize the folders (Block-level)
fileslevel1=dir(Subjectfolderpath);
Folderinfo=fileslevel1([fileslevel1.isdir]);
BlockNo={Folderinfo(3:end).name}; % For example: visit 1, visit 2, ...following visits
Rawdatapath=struct();
for i=1:length(BlockNo)
    Rawdatapath(i).EEG=fullfile(Subjectfolderpath,'\',BlockNo{i},'\EEG\');
    Rawdatapath(i).Nexus=fullfile(Subjectfolderpath,'\',BlockNo{i},'\Nexus\');
end

Filessavefolder=[Subjectfoldername,'_syndata (', datestr(datetime('today')),')']
mkdir(Filessavefolder);
%% Using EEGLab to import data ()
% Load EEG

%Block-level
for k=1:length(Rawdatapath)
    EEGfilenames={dir([Rawdatapath(k).EEG '*.vhdr']).name};
    [~, Conditionname, ~]=fileparts(EEGfilenames);
    Conditionname=cellstr(Conditionname)

    % Trial-level 
    for l=1:length(EEGfilenames)
        % EEG
        EEG=pop_loadbv(Rawdatapath(k).EEG, EEGfilenames{l});
        Events = find(cellfun(@(x) isequal(x, 'Stimulus'), {EEG.event.code})); % 
        EEGTriggers_start=EEG.event(Events(1)).latency;
        EEGTriggers_end=EEG.event(Events(end)-1).latency;
        Sampnb_EEG=EEGTriggers_end-EEGTriggers_start;
        EEG = pop_select(EEG, 'point',[EEGTriggers_start:EEGTriggers_end]);

        % Vicon
        acq = btkReadAcquisition([Rawdatapath(k).Nexus,Conditionname{l},'.c3d']);
        EMG = btkGetAnalogs(acq) ;
        Vicon_rate = btkGetAnalogFrequency(acq) ;

        Chaninfo_FP=fieldnames(EMG); Chaninfo_FP=Chaninfo_FP(1:12);
        Chaninfo_Rhythm = {'Force_1'}
        Chaninfo_Vicon_trigger = {'Synchronization_1'};
        Chaninfo_EMG = {''};
        Chaninfo_Vicon=[Chaninfo_FP; Chaninfo_Rhythm;Chaninfo_Vicon_trigger];

        % Analog-to-Digital Convert:
        f=10; n=3; 
        q=f/(2^n-1);
        EMGTrigger_adc=dec2bin(fix(EMG.(Chaninfo_Vicon_trigger{1})/q),n);
        EMGTrigger_adc=fix(EMG.(Chaninfo_Vicon_trigger{1})/q)*q       
        % Identify the start and the end
        TF=islocalmax(EMGTrigger_adc, 'FlatSelection','all'); % select the trigger in the start and the end
        Triggers_vicon=find(TF==1);
        EMGTrigger_start=Triggers_vicon(1);
        EMGTrigger_end=Triggers_vicon(length(Triggers_vicon)); % select the one before the last
        EMGTrigger_adc=EMGTrigger_adc(EMGTrigger_start:EMGTrigger_end)
        Sampnb_EMG=EMGTrigger_end-EMGTrigger_start;    

        % FP
        Data_FP=[];
        for i=1:length(Chaninfo_FP)
            Data_FP(:,i)=EMG.(Chaninfo_FP{i})( EMGTrigger_start:EMGTrigger_end,:) ; % transpose the matrix
        end
        vq_FP = interp1(1:length(Data_FP),Data_FP,linspace(1,length(Data_FP),length(EEG.data)),'spline');
        vq_FP = vq_FP'

        % Sound
        Data_Rhythm=[];
        for i=1:length(Chaninfo_Rhythm)
            Data_Rhythm(:,i) = EMG.(Chaninfo_Rhythm{i})( EMGTrigger_start:EMGTrigger_end,:);
        end
        vq_Rhythm = interp1(1:length(Data_Rhythm),Data_Rhythm,linspace(1,length(Data_Rhythm),length(EEG.data)),'spline');
        if size(vq_Rhythm)~=size(vq_FP(1,:)), vq_Rhythm = vq_Rhythm'; end

        % Vicon_trigger
        Data_Vicon_stim=[];
        for i=1:length(Chaninfo_Vicon_trigger)
            Data_Vicon_stim(:,i) = EMGTrigger_adc;
        end
        vq_Vicon_stim = interp1(1:length(Data_Vicon_stim),Data_Vicon_stim,linspace(1,length(Data_Vicon_stim),length(EEG.data)),'spline');
        if size(vq_Vicon_stim)~=size(vq_FP(1,:)), vq_Vicon_stim = vq_Vicon_stim'; end

        % EMG (n/a)
        % DataEMG=[];
        % for i=1:length(Chaninfo_EMG)
        %     DataEMG(:,i) = EMG.(Chaninfo_EMG{i})(Stim1:Stim2,:);
        % end
        
        % Uncomment below if you want to check the quality of the synchronized data:
        % EMGt=1:length(Data_FP); EEGt=1:length(EEG.data)
        % plot(EMGt/2000,Data_FP(:,1)', EEGt/2500, vq_FP(1,:),'g')

        syncdata = [EEG.data; vq_FP; vq_Rhythm; vq_Vicon_stim];

        for i=1:length(Chaninfo_Vicon)
            EEG.chanlocs(i+EEG.nbchan).labels = Chaninfo_Vicon{i}; 
            EEG.chanlocs(i+EEG.nbchan).type = 'Plateforme de Force'; EEG.chanlocs(i).ref = 'none';
        end
        EEG.chanlocs(size(EEG.data,1) ).type='trigger';
        EEG.data = syncdata ;
        EEG.nbchan =  size(EEG.data,1) ;
        EEG.duration=['Trial duration: EEG=',num2str(Sampnb_EEG/EEG.srate),'s; EMG=', num2str(Sampnb_EMG/Vicon_rate),'s']
        
        % Save a .mat and a .set file
        save([Parentfolderpath,'\',Subjectfoldername,'_',BlockNo{k},'_', Conditionname{l},'_sync.mat'],'EEG','syncdata')
        EEG = pop_saveset(EEG, [Subjectfoldername,'_',BlockNo{k},'_', Conditionname{l},'_sync.set'],[cd,'\',Filessavefolder]);
    end
end

