% DataSyn - Synchronize one or more EEG dataset (BrainVision format ex... 
% *.vhdr, *.eeg, *.vmrk) into structures. 
%
% Instruction:
% 1. Before using the function, please make sure you download:
%    1) eeglab toolbox (locally): "https://sccn.ucsd.edu/eeglab/download.php"
%                     (remotely): "\\10.89.24.15\e\Projet_EEG_Posture\eeglab14_1_2b\functions"        
%    2) BTK toolbox    (locally): "https://code.google.com/archive/p/b-tk/downloads"  *cannot run in MacOS M1/M2 
%                     (remotely): "\\10.89.24.15\e\Projet_ForceMusculaire\Fabien_ForceMusculaire\functions\btk"
%    3) FieldTrip toolbox (MATLAB add-on): "https://www.mathworks.com/matlabcentral/fileexchange/55891-fieldtrip#:~:text=FieldTrip%20is%20the%20MATLAB%20software%20toolbox%20for%20MEG,the%20Netherlands%20in%20close%20collaboration%20with%20collaborating%20institutes."
% 
% 2. Add both of them into your MATLAB path if needed. 
% 
% 3. Please indicate the folder of the participant (Subject-level), and follow
%    the folder structure if possible.
%
%    Folder structure: 
%
%       Subject-level folder (e.g., P1, P2) 
%                   |
%                  \|/
%                   V
%           Block-level folder (e.g., visit1, visit2 or block1, block2...)
%                   |
%                  \|/
%                   V
%       Condition-level folder (e.g., condition1, condition2 or trial 1, trial2...)
%
% 4. The script will creat a folder in your current cd and save the generated 
%    *.set files there. 
%
% Usage:
%   >> DataSyn('Subjectfolderpath');
%   >> [Experiment, Syncarray] = DataSyn('Subjectfolderpath'); 
%
%

function [Experiment, Syncarray]=DataSyn(Subjectfolderpath)

% Uncomment below if you haven't added the path of "eeglab" and "btk" 
% in your MATLAB. You can either access the toolboxes locally or remotely,
% please check the help section: 
% 
% eeglab_path = which('eeglab.m');
% addpath(eeglab_path);
% addpath(genpath('please add your btk toolbox path'));
%
% [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
eeglab('redraw');

Experiment=struct();
Syncarray=struct();

% Subjectfolderpath (char) has to be a directory
[~,Subjectfoldername,~] = fileparts(Subjectfolderpath);

% Recognize the folders (Block-level)
fileslevel1=dir(Subjectfolderpath);
Folderinfo=fileslevel1([fileslevel1.isdir]);
BlockNo={Folderinfo(3:end).name}; % For example: visit 1, visit 2, ...following visits
Rawdatapath=struct();

for i=1:length(BlockNo)
    Rawdatapath(i).EEG=fullfile(Subjectfolderpath,'\',BlockNo{i},'\EEG\');
    Rawdatapath(i).Nexus=fullfile(Subjectfolderpath,'\',BlockNo{i},'\Nexus\');
end

%Filessavefolder=[Filessavefolder, sprintf('_%02d',n)];
Filessavefolder=[Subjectfoldername,'_syncdata (', datestr(datetime('today')),')'];
mkdir(Filessavefolder);
%% Using EEGLab to import data ()
%Block-level
for k=1:length(Rawdatapath)
    EEGfilenames={dir([Rawdatapath(k).EEG '*.vhdr']).name};
    [~, Conditionname, ~]=fileparts(EEGfilenames);
    Conditionname=cellstr(Conditionname);

    % Trial-level 
    for l=1:length(EEGfilenames)
        % EEG
        EEG=pop_loadbv(Rawdatapath(k).EEG, EEGfilenames{l});
        Events = find(cellfun(@(x) isequal(x, 'Stimulus'), {EEG.event.code})); % 
        EEGTriggers=zeros(1,length(EEG.data));
        for m=1:length(Events)
            Frames = EEG.event(Events(m)).latency;
            EEGTriggers(Frames)=1;
        end
        TF=islocalmax(EEGTriggers,'MinSeparation',EEG.srate); % select the trigger in the start and the end
        Triggers_EEG=find(TF==1);
        EEGTriggers_start=Triggers_EEG(1);
        EEGTriggers_end=Triggers_EEG(end);
        Sampnb_EEG=EEGTriggers_end-EEGTriggers_start;
        EEG = pop_select(EEG, 'point',(EEGTriggers_start:EEGTriggers_end));

        % Vicon
        acq = btkReadAcquisition([Rawdatapath(k).Nexus,Conditionname{l},'.c3d']);
        EMG = btkGetAnalogs(acq) ;
        Vicon_rate = btkGetAnalogFrequency(acq) ;

        Chaninfo_FP=fieldnames(EMG); Chaninfo_FP=Chaninfo_FP(1:12);
        Chaninfo_Rhythm = {'Force_1'};
        Chaninfo_Vicon_trigger = {'Synchronization_1'};
        Chaninfo_EMG = {''};
        Chaninfo_Vicon=[Chaninfo_FP; Chaninfo_Rhythm;Chaninfo_Vicon_trigger];

        % Analog-to-Digital Convert:
        f=10; n=3; 
        q=f/(2^n-1);
        EMGTrigger_adc=dec2bin(fix(EMG.(Chaninfo_Vicon_trigger{1})/q),n);
        EMGTrigger_adc=fix(EMG.(Chaninfo_Vicon_trigger{1})/q)*q;       
        % Identify the start and the end
        TF=islocalmax(EMGTrigger_adc, 'FlatSelection','first', 'MinSeparation',Vicon_rate);        Triggers_vicon=find(TF==1);
        EMGTrigger_start=Triggers_vicon(1);
        EMGTrigger_end=Triggers_vicon(end); % select the one before the last
        EMGTrigger_adc=EMGTrigger_adc(EMGTrigger_start:EMGTrigger_end);
        Sampnb_EMG=EMGTrigger_end-EMGTrigger_start;    

        % FP
        Data_FP=[];
        for i=1:length(Chaninfo_FP)
            Data_FP(:,i)=EMG.(Chaninfo_FP{i})( EMGTrigger_start:EMGTrigger_end,:) ; % transpose the matrix
        end
        vq_FP = interp1(1:length(Data_FP),Data_FP,linspace(1,length(Data_FP),length(EEG.data)),'spline');
        vq_FP = vq_FP';

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
        EEG.duration=['Trial duration: EEG=',num2str(Sampnb_EEG/EEG.srate),'s; EMG=', num2str(Sampnb_EMG/Vicon_rate),'s'];
        
        if nargout>1
            Experiment.(['EEG_',Subjectfoldername,'_', BlockNo{k},'_', Conditionname{l}])= EEG;
            Syncarray.([Subjectfoldername,'_', BlockNo{k},'_', Conditionname{l}])= syncdata;
        else 
            Experiment.(['EEG_',Subjectfoldername,'_', BlockNo{k},'_', Conditionname{l}])= EEG;
        end 
        
        % Save a .mat and a .set file
        %save([Parentfolderpath,'\',Subjectfoldername,'_',BlockNo{k},'_', Conditionname{l},'_sync.mat'],'EEG','syncdata')
        setfilename= [Subjectfoldername,'_',BlockNo{k},'_', Conditionname{l},'_sync.set']
        %pop_saveset(EEG,setfilename,[cd,'\',Filessavefolder]);
        pop_saveset(EEG,setfilename,[cd]);

    end

    % setfile to BIDs
    cfg = [];
    cfg.method    = 'convert';
    cfg.datatype  = 'eeg';

  % specify the input file name, here we are using the same file for every subject
  cfg.dataset   = setfilename;  % Run the dataset in the syncfolder

  % specify the output directory
  cfg.bidsroot  = 'bids';
  cfg.sub       = Subjectfoldername;

  % specify the information for the participants.tsv file
  % this is optional, you can also pass other pieces of info
  %   cfg.participants.age = age(subindx);
  %   cfg.participants.sex = sex{subindx};

  % specify the information for the scans.tsv file
  % this is optional, you can also pass other pieces of info
  cfg.scans.acq_time = datestr(now, 'yyyy-mm-ddThh:MM:SS'); % according to RFC3339

  % specify some general information that will be added to the eeg.json file
  cfg.InstitutionName             = 'University of Montreal';
  cfg.InstitutionalDepartmentName = 'S2M';
  cfg.InstitutionAddress          = 'CEPSUM, Laval';

  % provide the mnemonic and long description of the task
  cfg.TaskName        =  Conditionname{l}; % how to read... 
  cfg.TaskDescription = 'Subjects were responding as fast as possible upon a change in a visually presented stimulus.';

  % these are EEG specific
  cfg.eeg.PowerLineFrequency = 60;   % since recorded in the USA
  cfg.eeg.EEGReference       = 'M1'; % actually I do not know, but let's assume it was left mastoid

  data2bids(cfg);

end
end 
