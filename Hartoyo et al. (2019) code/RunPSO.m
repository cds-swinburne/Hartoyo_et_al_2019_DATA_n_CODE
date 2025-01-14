function [best_paramset, err] = RunPSO(target_spec, seed)
%
% [best_paramset, err] = RunPSO(target_spec)
%   run particle swarm optimization to fit the model to the experimental spectrum target_spec
%   with a random starting point based on the seed given in the arguments
%   return the best parameter set and the error assosiated with it.
%

target_spec = [(zeros(8,1))', target_spec];

%--- define the physiological-relevant range of parameters ---
var_min(1) = 5;
var_max(1) = 150;

var_min(2) = 5;
var_max(2) = 150;

var_min(3) = 0.1;
var_max(3) = 1;

var_min(4) = 0.01;
var_max(4) = 0.5;

var_min(5) = 0.1;
var_max(5) = 2;

var_min(6) = 0.1;
var_max(6) = 2;

var_min(7) = 2000;
var_max(7) = 5000;

var_min(8) = 2000;
var_max(8) = 5000;

var_min(9) = 100;
var_max(9) = 1000;

var_min(10) = 100;
var_max(10) = 1000;

var_min(11) = 0;
var_max(11) = 10;

var_min(12) = 0;
var_max(12) = 10;

var_min(13) = -80;
var_max(13) = -60;

var_min(14) = -80;
var_max(14) = -60;

var_min(15) = -20;
var_max(15) = 10;

var_min(16) = -90;
var_max(16) = -65;

var_min(17) = 0.05;
var_max(17) = 0.5;

var_min(18) = 0.05;
var_max(18) = 0.5;

var_min(19) = -55;
var_max(19) = -40;

var_min(20) = -55;
var_max(20) = -40;

var_min(21) = 2;
var_max(21) = 7;

var_min(22) = 2;
var_max(22) = 7;

% ---- initial swarm position -----

inertia = 1.2;
max_ind_cor_factor = 2; % maximum individual correction factor
max_soc_cor_factor = 2; % maximum social correction factor

delta_threshold = 1.0e-10; % idealistic targeted tiny cost

rng(seed)

swarm_size = 80;
swarm = zeros(swarm_size,4,22);

for iter = 1 : 22
    swarm(1:swarm_size, 1, iter) = var_min(iter)+rand(1,swarm_size)*(var_max(iter)-var_min(iter));
end

swarm(:, 4, 1) = 1000;          % best value so far
swarm(:, 2, :) = 0;             % initial velocity

vbest = 1000;
prev_vbest = 1000;
stuck = 0;
count = 0;

% Iterations
while (vbest > delta_threshold)
    count = count + 1;
    
    %-- evaluating position & quality ---
    for i = 1 : swarm_size
        
        vars = zeros(22);
        for z = 1 : 22
            vars(z) = swarm(i, 1, z);
        end
        
        val = computeCost(vars);         % fitness evaluation (you may replace this objective function with any function having a global minima)
        
        if val < swarm(i, 4, 1)                 % if new position is better
            
            for z = 1 : 22
                swarm(i, 3, z) = vars(z); % update best x,
            end
            
            swarm(i, 4, 1) = val;               % and best value
        end
        
        for z = 1 : 22
            swarm(i, 1, z) = swarm(i, 1, z) + swarm(i, 2, z)/1.3;     %update x position
        end
    end
    
    prev_vbest = vbest;
    
    [vbest,gbest] = min(swarm(:, 4, 1));        % global best position
    
    %--- stopping condition ---
    if prev_vbest - vbest < vbest/500
        stuck = stuck + 1;
    else
        stuck = 0;
    end
    
    if stuck > 100
        break
    end
    
    %--- updating velocity vectors
    for i = 1 : swarm_size
        for z = 1 : 22
            swarm(i, 2, z) = rand*inertia*swarm(i, 2, z) + max_ind_cor_factor*rand*(swarm(i, 3, z) - swarm(i, 1, z)) + max_soc_cor_factor*rand*(swarm(gbest, 3, z) - swarm(i, 1, z));   %x velocity component
        end
    end
end

best_paramset = zeros(1,22);
for z = 1 : 22
    best_paramset(z) = swarm(gbest, 3, z);
end

err = vbest;



    function cost = computeCost(params)
        % function for computing cost given the parameter set params
        
        %--- check the stability of the solution ---
        [is_fixed_point_found, is_chaotic, jac] = CheckSolution(params);
        
        %--- check if all parameters are in physiolocially-relevant range
        physiological = 1;
        for x = 1:22
            newVal = params(x);
            if newVal < var_min(x) || newVal > var_max(x)
                physiological = 0;
                break;
            end
        end
        
        if (is_fixed_point_found == 0)
            cost = 10000;  % huge cost in case fixed point not found
        else
            if (is_chaotic == 1)
                cost = 1000; % huge cost in case fixed of chaotic/unstable solution
            else
                if (physiological == 0)
                    cost = 100; % huge cost in case of parameters not in physiological-relevant range
                else
                    %--- compute the model spectrum
                    freq = (0:80)'/4;
                    
                    spec = zeros(81,1);
                    for k=1:81
                        spec(k) = getAmplitude(freq(k), jac);
                    end
                    
                    %--- compute the normalization/scaling factor
                    num = 0;
                    for k=9:81
                        num = num + spec(k)*target_spec(k)*0.25;
                    end
                    
                    den = 0;
                    for j=9:81
                        den = den + spec(j)*spec(j)*0.25;
                    end
                    
                    g = num/den;
                    
                    %--- compute cost
                    cost = 0;
                    for x=9:81
                        cost = cost + (g*spec(x) - target_spec(x))^2;
                    end
                end
            end
        end
    end

    function amplitude = getAmplitude(f, jacobian)
    %function to compute the model power spectrum given the Jacobian matrix and
    %sampling frequency
    
        Jm = jacobian - 0.002i*pi*f*eye(10);
        G = [0 0 0 1 0 0 0 0 0 0]';
        Y = Jm\G;
        amplitude = abs(Y(1,1));
        amplitude = amplitude.^2;
    end

end
