function [ block_data, allOutputData ] = run_trials_MM( tasks, run_obj, scanimage_client, blockCoreName )

global s

% Setup data structures for read / write on the daq board
s = daq.createSession('ni');

% Input channels:
%
%   Dev1:
%       AI.4 = FicTrac X
%       AI.5 = FicTrac Yaw
%       AI.6 = FicTrac Y
%       AI.7 = Camera strobe
%
% Output channels:
%
%   Dev1:
%       P0.0        = external trigger for scanimage
%       AO.2        = speaker output
%       P0.1        = olfactometer valve A/shutoff B
%       P0.2        = olfactometer valve B/shutoff A
%       P0.3        = olfactometer NO valve ("dummy")
%       P0.4        = trial alignment fiber LED
%       P0.7        = camera trigger

% This channel is lfor external triggering of scanimage 5.1
s.addDigitalChannel('Dev1', 'port0/line0', 'OutputOnly');

% Add output channel for speaker
s.addAnalogOutputChannel('Dev1', 2, 'Voltage');

% Add output channels for olfactometer (1-3), fiber LED (4) and camera trigger (7)
chanIDs = {'port0/line1', 'port0/line2', 'port0/line3', 'port0/line4', 'port0/line7'};
s.addDigitalChannel('Dev1', chanIDs, 'OutputOnly');

% Add analog input channels for FicTrac (4-6) and camera strobe (7) data
s.addAnalogInputChannel('Dev1', 4:7, 'Voltage');

% Set up params
SAMPLING_RATE = 4000;
s.Rate = SAMPLING_RATE;
FRAME_RATE = 25; % This is the behavior camera frame rate

nTrials = run_obj.nTrials;
trialDuration = run_obj.trialDuration;
blockDuration = trialDuration * nTrials;

allOutputData = [];
for iTrial = 1:nTrials
    
    % Parse task name
    currTask = tasks{iTrial};
    taskDivs = strfind(currTask, '-');
    taskType = currTask(1:taskDivs(1)-1);
    stimOnset = str2double(currTask(taskDivs(2)+1:taskDivs(3)-1));
    stimDur = str2double(currTask(taskDivs(4)+1:end));
    
    % Initialize the output vectors to zero
    zeroStim = zeros(SAMPLING_RATE * trialDuration, 1);
    stimCommand = zeroStim;
    cameraTrigger = zeroStim;

    % Set up stim output
    stimStartTime = stimOnset;
    stimEndTime = stimStartTime + stimDur;
    pairStimStartTime = stimEndTime + stimDur;
    pairStimEndTime = pairStimStartTime + stimDur;
    stimStartSample = round(stimStartTime * SAMPLING_RATE);
    stimEndSample = round(stimEndTime * SAMPLING_RATE);
    pairStimStartSample = round(pairStimStartTime * SAMPLING_RATE);
    pairStimEndSample = round(pairStimEndTime * SAMPLING_RATE);

    % Create stim output vectors
    stimCommand(stimStartSample:stimEndSample) = 1;
    pulseStimCommand = stimCommand;
    latePulseCommand = zeroStim;
    analogStimCommand = stimCommand * 10;
    pulseStimCommand(pairStimStartSample:pairStimEndSample) = 1;
    latePulseCommand(pairStimStartSample:pairStimEndSample) = 1;

    % Create speaker output vector
    speakerStimCommand = zeroStim;
    f = 200;
    ts = 1/SAMPLING_RATE;
    t = 0:ts:stimDur;
    sineTone = sin(2*pi*f*t) * 10;
    speakerStimCommand(stimStartSample:stimEndSample) = sineTone;
    
    % Set up camera trigger output
    triggerInterval = SAMPLING_RATE / FRAME_RATE;
    framesPerTrial = (trialDuration * SAMPLING_RATE) / triggerInterval;
    if mod(triggerInterval, 1) || mod(framesPerTrial, 1)
       disp('WARNING: frame count errors due to camera trigger timing are likely!') 
    end
    cameraTrigger(1:round(triggerInterval):end) = 1;
    
    % Set up alignment LED output
    alignLEDCommand = zeroStim;
    alignLEDCommand(1:triggerInterval - 1) = 1;
    alignLEDCommand(end-(triggerInterval - 1):end) = 1;
    
    % Set up Scanimage start/next file trigger
    imagingTrigger = zeroStim;
    imagingTrigger(1:1000) = 1;
    imagingTrigger(end) = 0;
    
    
    % output_data =         [imaging trigger    speaker,            valve A/shutoff B,  valve B/shutoff A,  NO valve,           alignment LED,   cameraTrigger]
    switch taskType
        case 'OdorA'
            outputData =    [imagingTrigger,    zeroStim,           stimCommand,        zeroStim,           stimCommand,        alignLEDCommand, cameraTrigger];
        case 'OdorB'
            outputData =    [imagingTrigger,    zeroStim,           zeroStim,           stimCommand,        stimCommand,        alignLEDCommand, cameraTrigger];
        case 'OdorAPair'
            outputData =    [imagingTrigger,    zeroStim,           pulseStimCommand,   zeroStim,           pulseStimCommand,   alignLEDCommand, cameraTrigger];
        case 'OdorBPair'
            outputData =    [imagingTrigger,    zeroStim,           zeroStim,           pulseStimCommand,   pulseStimCommand,   alignLEDCommand, cameraTrigger];
        case 'OdorABPair'
            outputData =    [imagingTrigger,    zeroStim,           stimCommand,        latePulseCommand,   pulseStimCommand,   alignLEDCommand, cameraTrigger];
        case 'OdorBAPair'
            outputData =    [imagingTrigger,    zeroStim,           latePulseCommand,   stimCommand,        pulseStimCommand,   alignLEDCommand, cameraTrigger];
        case {'NoOdor', 'NoStim'}
            outputData =    [imagingTrigger,    zeroStim,           zeroStim,           zeroStim,           zeroStim,           alignLEDCommand, cameraTrigger];
        case 'AirStop'
            outputData =    [imagingTrigger,    zeroStim,           zeroStim,           zeroStim,           stimCommand,        alignLEDCommand, cameraTrigger];
        case 'Sound'
            outputData =    [imagingTrigger,    speakerStimCommand, zeroStim,           zeroStim,           zeroStim,           alignLEDCommand, cameraTrigger];
        otherwise
            disp('Warning: unrecognized stim type...running trial with no stim.')
            outputData =    [imagingTrigger,    zeroStim,           zeroStim,           zeroStim,           zeroStim,           alignLEDCommand, cameraTrigger];
    end
    allOutputData = cat(1, allOutputData, outputData);
end%iTrial

allOutputData(end, :) = 0; % To make sure the stim doesn't stay on at end of block
queueOutputData(s, allOutputData);

% Trigger scanimage run if using 2p.
if(run_obj.using2P == 1)
    scanimage_file_str = ['cdata_' blockCoreName '_dur_', num2str(blockDuration), '_nTrials_', num2str(nTrials)];
    fprintf(scanimage_client, [scanimage_file_str]);
    disp(['Wrote: ' scanimage_file_str ' to scanimage server' ]);
    acq = fscanf(scanimage_client, '%s');
    disp(['Read acq: ' acq ' from scanimage server' ]);
end

% Delay starting the aquisition for 2 seconds to ensure that scanimage is ready
pause(1.0);

[block_data, ~] = s.startForeground();

release(s);
end