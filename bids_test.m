sub = {'001'};

% for subject 3 the age is unknown, for subject 2 the sex is not specified
age = [11];
sex = {'f'};

for subindx=1:numel(sub)

  cfg = [];
  cfg.method    = 'copy';
  cfg.datatype  = 'eeg';

  % specify the input file name, here we are using the same file for every subject
  cfg.dataset   = 'P2_01_cuedPref_sync.set';

  % specify the output directory
  cfg.bidsroot  = 'bids';
  cfg.sub       = sub{subindx};

  % specify the information for the participants.tsv file
  % this is optional, you can also pass other pieces of info
  cfg.participants.age = age(subindx);
  cfg.participants.sex = sex{subindx};

  % specify the information for the scans.tsv file
  % this is optional, you can also pass other pieces of info
  cfg.scans.acq_time = datestr(now, 'yyyy-mm-ddThh:MM:SS'); % according to RFC3339

  % specify some general information that will be added to the eeg.json file
  cfg.InstitutionName             = 'University of California San Diego';
  cfg.InstitutionalDepartmentName = 'Schwartz Center for Computational Neuroscience';
  cfg.InstitutionAddress          = '9500 Gilman Drive # 0559; La Jolla CA 92093, USA';

  % provide the mnemonic and long description of the task
  cfg.TaskName        = 'cuedPref';
  cfg.TaskDescription = 'Subjects were responding as fast as possible upon a change in a visually presented stimulus.';

  % these are EEG specific
  cfg.eeg.PowerLineFrequency = 60;   % since recorded in the USA
  cfg.eeg.EEGReference       = 'M1'; % actually I do not know, but let's assume it was left mastoid

  data2bids(cfg);

end