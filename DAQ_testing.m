
% Setup data structures for read / write on the daq board
s = daq.createSession('ni');

% Add output channels
s.addAnalogOutputChannel('Dev1', 0, 'Voltage');
s.addDigitalChannel('Dev1', ['port0/line4'], 'OutputOnly');
s.addDigitalChannel('Dev1', ['port0/line8'], 'OutputOnly');
 

SAMPLING_RATE = 1000;
s.Rate = SAMPLING_RATE; 
% chanSecDur = round(duration * 60 / 2);
% chanSampDur = round(chanSecDur * SAMPLING_RATE);

% % Initialize the output vectors to zero
% zeroStim = zeros(chanSampDur * 2, 1);
% chanACommand = zeroStim;
% chanBCommand = zeroStim;
% dummyCommand = zeroStim;

% % Create stim output vectors
% chanACommand(1:chanSampDur) = 1;
% chanBCommand(chanSampDur:end) = 1;
% dummyCommand(:) = 1;

% outputData = [zeroStim, chanACommand, chanBCommand, chanBCommand, chanACommand, dummyCommand];
% outputData(end, :) = 0; % To make sure the DAQ doesn't stay on between trials
nSamples = 300000;
outputData = [ones(nSamples,1)*10, ones(nSamples, 1), ones(nSamples, 1)];
outputData(end, :) = 0;
queueOutputData(s, outputData);

s.startForeground();
release(s);