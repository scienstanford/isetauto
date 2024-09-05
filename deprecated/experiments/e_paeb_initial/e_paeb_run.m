function  e_paeb_run(params)
%E_PAEB_RUN run pedestrian aeb experiment in matlab experiment manager

    % Pass params in using static methods of our scenario class, since
    % we don't have an object of the class yet
    ia_drivingScenario.initialSpeed(params.initialSpeed);
    
    % some code won't run right in an experiment
    ia_drivingScenario.inExperiment(true); 

    % this is the driving scenario function exported from the DSD
    % modified to invoke our version of driving scenario.
    initialPAEBTest();

end

