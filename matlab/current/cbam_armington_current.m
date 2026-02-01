clear; clc;

% ============================================================
% cbam_armington_current.m
% "Current" (scalable) version of the PoC:
% - S=3 sectors: steel, aluminum, other non-ferrous
% - Metals split loaded from data_processed/metals_split_params_2014.csv
% - CBAM wedges only applied to steel & aluminum
% - Calibration targets only steel & aluminum (Colmer)
% ============================================================

% ---- Robust paths (works regardless of MATLAB current folder)
thisDir = fileparts(mfilename('fullpath'));         % .../matlab/current
repoDir = fileparts(fileparts(thisDir));            % repo root
dataProcessedDir = fullfile(repoDir, 'data_processed');
outputDir        = fullfile(repoDir, 'output');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Ensure we can find functions in matlab/current
addpath(thisDir);
rehash;

% ---- Load metals split parameters (OECD C24A/C24B + COMEXT aluminum share)
metalsFile = fullfile(dataProcessedDir, 'metals_split_params_2014.csv');
metals = readtable(metalsFile);

% ---- Dimensions
N = 2;   % 1 = EU, 2 = non-EU
S = 3;   % 1 = steel, 2 = aluminum, 3 = other non-ferrous
mu = 1;

% ---- Baseline incomes (levels don't matter for PoC)
Yi = [1; 1];
Yi3D = repmat(reshape(Yi,[N 1 1]), [1 N S]);   % size N x N x S

% ---- No trade imbalances for PoC
Dj3D   = zeros(N,N,S);
Dj_h3D = zeros(N,N,S);

% ---- Sector expenditure weights beta_{j,s} (replicated across i)
betajs3D = zeros(N,N,S);

% Map "EU" and "non-EU" to proxy countries in metals table
eu_proxy  = 'DEU';
neu_proxy = 'TUR';

eu_row  = strcmp(metals.country, eu_proxy);
neu_row = strcmp(metals.country, neu_proxy);

if ~any(eu_row)
    error("EU proxy '%s' not found in metals table.", eu_proxy);
end
if ~any(neu_row)
    error("Non-EU proxy '%s' not found in metals table.", neu_proxy);
end

betaEU  = [ ...
    metals.share_steel_in_c24(eu_row), ...
    metals.share_al_in_c24(eu_row), ...
    metals.share_other_nf_in_c24(eu_row) ...
];

betaNEU = [ ...
    metals.share_steel_in_c24(neu_row), ...
    metals.share_al_in_c24(neu_row), ...
    metals.share_other_nf_in_c24(neu_row) ...
];

for j = 1:N
    if j == 1
        betajs3D(:,j,1) = betaEU(1);
        betajs3D(:,j,2) = betaEU(2);
        betajs3D(:,j,3) = betaEU(3);
    else
        betajs3D(:,j,1) = betaNEU(1);
        betajs3D(:,j,2) = betaNEU(2);
        betajs3D(:,j,3) = betaNEU(3);
    end
end

disp('betaEU [steel, aluminum, otherNF]:');  disp(betaEU);
disp('betaNEU [steel, aluminum, otherNF]:'); disp(betaNEU);

% ---- Baseline import shares lambda_{i,j,s} (sum over i = 1 for each j,s)
Lijs3D = zeros(N,N,S);

% Steel (s=1): EU buys 70% from EU, 30% from non-EU; non-EU buys 60% domestic
Lijs3D(:,1,1) = [0.70; 0.30];
Lijs3D(:,2,1) = [0.40; 0.60];

% Aluminum (s=2): EU buys 60% from EU, 40% from non-EU; non-EU buys 65% domestic
Lijs3D(:,1,2) = [0.60; 0.40];
Lijs3D(:,2,2) = [0.35; 0.65];

% Other non-ferrous (s=3): placeholder pattern (same as aluminum)
Lijs3D(:,1,3) = Lijs3D(:,1,2);
Lijs3D(:,2,3) = Lijs3D(:,2,2);

% ---- Elasticities: sigma = epsilon + 1
epsilon = [5, 5, 5];
sigma   = epsilon + 1;

sigma_s3D = zeros(N,N,S);
for s = 1:S
    sigma_s3D(:,:,s) = sigma(s);
end

% ---- Trade wedges: baseline tariffs, counterfactual tariffs, iceberg hats
tijs3D     = zeros(N,N,S);
tijs_p3D   = zeros(N,N,S);
tauijs_h3D = ones(N,N,S);

disp('Step 3 complete: baseline objects created.');

% ---- CBAM shock: tariff-like wedge on imports into EU (j=1) from non-EU (i=2)
cbam_tau = 0.10;                  % 10% test
tijs_p3D(2,1,1) = cbam_tau;       % steel
tijs_p3D(2,1,2) = cbam_tau;       % aluminum
% (s=3 otherNF gets no CBAM wedge)

% ---- Solve for wage hats with fsolve
X0 = ones(N,1);

syst = @(X) DEK_TRF_SYSTEM_N1(X, N, S, mu, Yi3D, Dj3D, Dj_h3D, ...
                              betajs3D, sigma_s3D, tijs3D, tijs_p3D, ...
                              tauijs_h3D, Lijs3D);

opts = optimset('Display','off','MaxIter',2000,'TolFun',1e-12,'TolX',1e-12);

[wi_h, fval] = fsolve(syst, X0, opts);

disp('max residual:'); disp(max(abs(fval)));
disp('wage hats (EU, non-EU):'); disp(wi_h);

% ---- Compute sector price index hats for each importer j and sector s
phi = tauijs_h3D .* (1+tijs_p3D) ./ (1+tijs3D);  % delivered wedge hat

P_hat = zeros(N,S);
for j = 1:N
    for s = 1:S
        sig = sigma(s);
        tmp = 0;
        for i = 1:N
            tmp = tmp + Lijs3D(i,j,s) * (phi(i,j,s)*wi_h(i))^(1 - sig);
        end
        P_hat(j,s) = tmp^(1/(1 - sig));
    end
end

disp('EU sector price hats [steel, aluminum, otherNF]:');
disp(P_hat(1,:));

% =========================
% Step 6: Calibrate single cbam_tau by matching Colmer targets
% =========================
target = [1.0084, 1.0458];      % [steel, aluminum] hats (Colmer)
grid = 0.00:0.01:0.30;

P_EU = nan(length(grid), S);
loss = nan(length(grid), 1);

for g = 1:length(grid)
    cbam_tau = grid(g);

    % reset counterfactual tariffs
    tijs_p3D(:) = 0;
    tijs_p3D(2,1,1) = cbam_tau;   % steel
    tijs_p3D(2,1,2) = cbam_tau;   % aluminum

    % solve wages (minimize squared residuals)
    obj = @(X) sum( DEK_TRF_SYSTEM_N1(X, N, S, mu, Yi3D, Dj3D, Dj_h3D, ...
                                      betajs3D, sigma_s3D, tijs3D, tijs_p3D, ...
                                      tauijs_h3D, Lijs3D ).^2 );

    wi_h_tmp = fminsearch(obj, ones(N,1), optimset('Display','off','TolX',1e-10,'TolFun',1e-12));

    % compute EU sector price hats
    phi = tauijs_h3D .* (1+tijs_p3D) ./ (1+tijs3D);
    for s = 1:S
        sig = sigma(s);
        tmp = 0;
        for i = 1:N
            tmp = tmp + Lijs3D(i,1,s) * (phi(i,1,s)*wi_h_tmp(i))^(1 - sig);
        end
        P_EU(g,s) = tmp^(1/(1 - sig));
    end

    % loss vs targets (match ONLY steel+aluminum)
    loss(g) = sum((P_EU(g,1:2) - target).^2);
end

[~, idx] = min(loss);
best_tau = grid(idx);

disp('--- Calibration result ---')
disp(['Best cbam_tau: ', num2str(best_tau)])
disp('Matched EU price hats [steel, aluminum]:')
disp(P_EU(idx,1:2))
disp('Targets [steel, aluminum]:')
disp(target)

% =========================
% Step 7: Sector-specific CBAM wedges (steel and aluminum separately)
% =========================
target = [1.0084, 1.0458];   % Colmer targets: [steel, aluminum]

obj2 = @(tau) obj_prices_only12(tau, target, ...
    N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D,sigma_s3D,tijs3D,tauijs_h3D,Lijs3D);

% initial guess: start near plausible values
tau0 = [0.03; 0.10];   % [steel, aluminum]

[tau_hat, loss_val] = fminsearch(obj2, tau0, ...
    optimset('Display','iter','TolX',1e-10,'TolFun',1e-12));

disp('--- Sector-specific calibration ---')
disp('Calibrated CBAM wedges [steel, aluminum]:')
disp(tau_hat)
disp('Loss:')
disp(loss_val)

results = struct();
results.tau_single_best = best_tau;               % from Step 6
results.tau_sector = tau_hat;                     % [tau_steel; tau_alum] from Step 7
results.loss_sector = loss_val;
results.targets = target;
results.N = N; results.S = S;
results.Yi = Yi;
results.Lijs3D = Lijs3D;
results.sigma = sigma;
results.betaEU  = betaEU;
results.betaNEU = betaNEU;
results.eu_proxy  = eu_proxy;
results.neu_proxy = neu_proxy;

save(fullfile(outputDir,'cbam_current_results.mat'),'results');


% =========================
% Local helper function(s)
% =========================
function val = obj_prices_only12(tau, target, ...
    N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D,sigma_s3D,tijs3D,tauijs_h3D,Lijs3D)

    p = compute_prices(tau(1), tau(2), ...
        N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
        sigma_s3D,tijs3D,tauijs_h3D,Lijs3D);

    val = sum((p(1:2) - target).^2);
end