function [ output_args ] = start_trials_MM( run_obj )


metaData = [];
STIM_TYPE = 'Task File';

if(strcmp(STIM_TYPE, 'Task File') == 1)
    
    % Read task file
    taskFilePath = run_obj.taskFilePath;
    disp(['About to start trials using task file: ' taskFilePath]);
    tasks = read_task_file(taskFilePath);
    nTasks = length(tasks); 
    
    % Connect to scanimage
    scanimage_client_skt = '';
    if run_obj.using2P
        scanimage_client_skt = connect_to_scanimage();
        disp('Connected to scanimage server');
    end

    sid = run_obj.sid;
    run_obj.nTrials = nTasks;
    
    % Make sure temporary camera save directory doesn't already have images
    tempDir = 'C:\tmp\*';
    dirContents = dir(tempDir(1:end-1));
    if length(dirContents) > 2
        disp('WARNING: one or more images already exist in temporary video frame save directory')
    end
    delete('C:\tmp\*.tif');
    
    % Run trials
    currBlockCoreName = [datestr(now, 'yyyymmdd_HHMMSS'), '_sid_', num2str(sid), '_block_', ];
    allTasks = cellfun(@(x) regexprep(x, '_', '-'), tasks, 'UniformOutput', 0);
    if contains(currTask, 'Closed_Loop')
        [~, outputData] = run_trials_MM_CL(allTasks, run_obj, scanimage_client_skt, currBlockCoreName );
    else
        [~, outputData] = run_trials_MM(allTasks, run_obj, scanimage_client_skt, currBlockCoreName );
    end

    % Save ball data
    save([run_obj.expDir '\fictracData_' currTrialCoreName '.mat'], 'fictracData')
        
    % Save metadata
    metaData.nTrials = run_obj.nTrials;
    metaData.trialDuration = run_obj.trialDuration;
    metaData.stimTypes = tasks;
    metaData.sid = run_obj.sid;
    metaData.taskFile = run_obj.taskFilePath;
    metaData.outputData = outputData;
    save([run_obj.expDir '\metadata_' currTrialCoreName '.mat'], 'metaData', 'trial_time');
        
    % Move video frames from temp directory to appropriate location:
    savePath = [run_obj.expDir, '\', currTrialCoreName, '\'];
        
    % Create save directory for video frames if it doesn't already exist
    if ~isdir(savePath)
        mkdir(savePath)
    end
        
    % Move frames
    tic
    try
        movefile(tempDir, savePath, 'f')
    catch
        disp('Warning: behavior camera not recording!')
    end
    disp(['Moving video frames took ', sprintf('%0.2f', toc), ' sec']);
    
    % Close scanimage connection
    if run_obj.using2P
        fprintf(scanimage_client_skt, 'END_OF_SESSION');
        fclose(scanimage_client_skt);
    end
    disp('Trials complete.')
else
    disp(STIM_TYPE);
    disp(['ERROR: stim_type: ' STIM_TYPE ' is not supported.']);
end%if

end

