function [trialData, outputData, columnLabels] = run_panels_trial(metadata, scanimageClient)


mD = metadata;
tS = metadata.trialSettings;

% Create session object, making it global so the GUI can try and interrupt it if necessary
global s
s = daq.createSession('ni');
s.Rate = mD.SAMPLING_RATE;

% Input channels:
%   Dev1:
%       AI.11  = Panels X dim position telegraph
%       AI.12  = Panels Y dim position telegraph
%
% Output channels:
%
%   Dev1:
%       P0.0        = "Start Acqusition" trigger for scanimage
%       P0.6        = LED opto stim command
%       P0.4        = trial alignment fiber LED
%       P0.?        = panels start trigger?

%%% ---------- SET UP DAQ CHANNELS ---------- %%%

% Add analog input channels for panels position telegraph outputs
s.addAnalogInputChannel('Dev1', 11:12, 'Voltage');

% This channel is for external triggering of scanimage
s.addDigitalChannel('Dev1', 'port0/line0', 'OutputOnly');

% Output channel for opto stim LED
s.addDigitalChannel('Dev1', 'port0/line6', 'OutputOnly');

% Trial alignment LED command
s.addDigitalChannel('Dev1', 'port0/line4', 'OutputOnly');

% % Panels start trigger
% s.addDigitalChannel('Dev1', 'port0/line ', 'OutputOnly');

% Create labels for columns of recorded data array
columnLabels.in = {'PanelsXDimTelegraph', 'PanelsYDimTelegraph'};

%%% ---------- SET UP OUTPUT DATA ---------- %%%

% Initialize base output vector
zeroStim = zeros(mD.SAMPLING_RATE * tS.trialDuration, 1);

% Scanimage trigger
siTrigger = zeroStim; 
siTrigger(1:1000) = 1;

% Opto stim LED command
optoStimCommand = zeroStim;
if tS.usingOptoStim
    startTime = tS.optoStimTiming(1);
    stimDur = tS.optoStimTiming(2);
    isi = tS.optoStimTiming(3);
    
    % Convert timing to samples
    startSample = startTime * mD.SAMPLING_RATE;
    stimDurSamples = stimDur * mD.SAMPLING_RATE;
    isiSamples = isi * mD.SAMPLING_RATE;
    
    % Find start and end of each stimulus in the trial
    allStimStartSamples = startSample:(stimDurSamples + isiSamples):numel(zeroStim);
    allStimEndSamples = allStimStartSamples + stimDurSamples;
    
    % Cut off any stims that are interrupted by the end of the trial
    allStimStartSamples(allStimStartSamples >= (numel(zeroStim) - stimDurSamples)) = [];
    allStimEndSamples(allStimEndSamples >= numel(zeroStim)) = [];
    
    % Fill in stimulus epochs in command vector, using PWM if appropriate
    for iStim = 1:numel(allStimStartSamples)
        if tS.usePWM
            pwmPeriodSamples = round(mD.SAMPLING_RATE / tS.PWMFreq);
            pulseWidth = round(pwmPeriodSamples * (tS.PWMDutyCycle / 100));
            for iSamp = 1:pulseWidth
               currStart = allStimStartSamples(iStim);
               currEnd = allStimEndSamples(iStim);
               optoStimCommand(currStart + iSamp:pwmPeriodSamples:currEnd) = 1; 
            end
        else
            optoStimCommand(allStimStartSamples(iStim):allStimEndSamples(iStim)) = 1;
        end
    end%iStim
end%if

% Alignment IR LED command 
alignLEDCommand = zeroStim;
LEDOnSamples = mD.SAMPLING_RATE * 0.1; % LED on for first and last 100 ms of trial
alignLEDCommand(1:LEDOnSamples) = 1;
alignLEDCommand(end-LEDOnSamples:end) = 1;

% % Panels
% panelsStartTrigger = siStartTrigger % sending the same trigger command to scanimage and the panels
disp(numel(siTrigger))
disp(numel(optoStimCommand))
disp(numel(alignLEDCommand))
% Create and queue output data array
outputData = [siTrigger, optoStimCommand, alignLEDCommand];
outputData(end, :) = 0; % To make sure everything turns off at the end of the trial
queueOutputData(s, outputData);
s.Rate = mD.SAMPLING_RATE;

% Create column labels for output data
columnLabels.out = {'ScanImageStartTrigger', 'OptoStimCommand', 'AlignmentLEDCommand'};

% Get scanimage ready if using 2P
if tS.using2P
   % Sending string containing file naming and trial duration info for scanimage to use
   siFileStr =  [mD.expID, '_', tS.expName, '_trial_', num2str(mD.trialNum), '_dur_', ...
            num2str(tS.trialDuration)];
   fprintf(scanimageClient, siFileStr);
   disp(['Wrote: ', siFileStr, ' to scanimage server']);
   pause(1)
   siClientResponse = fscanf(scanimageClient, '%s');
   disp('Read: ', siClientResponse, ' from scanimage server');
   
   % Wait for another couple of seconds to make sure scanimage is really ready
pause(2)
end

% Start the panels, immediately followed by the trial session
Panel_com('start');
[trialData, ~] = s.startForeground();
release(s);

end