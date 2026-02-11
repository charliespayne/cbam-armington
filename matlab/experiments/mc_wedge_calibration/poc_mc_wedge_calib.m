clear; clc;

% --- Find repo root by walking up until we see a .git folder ---
here = fileparts(mfilename('fullpath'));   % folder containing THIS script
repo_root = here;

while ~isfolder(fullfile(repo_root, '.git'))
    parent = fileparts(repo_root);
    if strcmp(parent, repo_root)
        error('Could not find repo root (no .git folder found above %s).', here);
    end
    repo_root = parent;
end

cd(repo_root);
disp("Repo root: " + pwd);
core_dir = fullfile(repo_root, 'matlab', 'core');
addpath(core_dir);
rehash;
% ============================================================
% Marginal-cost wedge PoC:
% - Replace tariff-like CBAM wedge with "mc wedge" that scales
%   delivered unit costs for targeted flows/sectors.
% - Calibrate wedges to match target EU price hats (steel, alum).
% ============================================================

% ---- Load metals split parameters (OECD C24A/C24B + COMEXT alum share)
metals_path = fullfile(repo_root, 'data_processed', 'metals_split_params_2014.csv');
disp("Reading: " + metals_path);

metals = readtable(metals_path);

% ---- Dimensions
N = 2;              % 1 = EU, 2 = non-EU
S = 3;              % 1=steel, 2=aluminum, 3=other non-ferrous
mu = 1;

% ---- Baseline incomes (levels don't matter for PoC)
Yi = [1; 1];
Yi3D = repmat(reshape(Yi,[N 1 1]), [1 N S]);   % size N x N x S

% ---- No trade imbalances for PoC
Dj3D   = zeros(N,N,S);
Dj_h3D = zeros(N,N,S);

% ---- Sector expenditure weights beta_{j,s} (replicated across i)
betajs3D = zeros(N,N,S);

% Map "EU" and "non-EU" to specific proxy countries in metals table
eu_proxy  = 'DEU';
neu_proxy = 'TUR';

eu_row  = strcmp(metals.country, eu_proxy);
neu_row = strcmp(metals.country, neu_proxy);

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
% NOTE: if you've already computed WIOD-based 2x2 shares, plug them in here.
Lijs3D = zeros(N,N,S);

% Example: use the same shares for all 3 sectors (replace with your WIOD matrix if available)
% EU importer (j=1): [EU; nonEU]
L_EU = [0.8721; 0.1279];
% nonEU importer (j=2): [EU; nonEU]
L_NEU = [0.0204; 0.9796];

for s = 1:S
    Lijs3D(:,1,s) = L_EU;
    Lijs3D(:,2,s) = L_NEU;
end

disp('Check sum_i lambda(i,j,s):');
disp(squeeze(sum(Lijs3D,1)));

% ---- Elasticities: sigma = epsilon + 1
epsilon = [5, 5, 5];
sigma   = epsilon + 1;

sigma_s3D = zeros(N,N,S);
for s = 1:S
    sigma_s3D(:,:,s) = sigma(s);
end

% ---- Trade wedges: keep tariffs OFF in this PoC
tijs3D     = zeros(N,N,S);
tijs_p3D   = zeros(N,N,S);

% ---- Iceberg hats baseline = 1
tauijs_h3D = ones(N,N,S);

disp('Step 0 complete: baseline objects created.');

% ============================================================
% MC WEDGE DEFINITION
% We implement a "delivered unit cost hat" multiplier:
%   delivered_hat(i,j,s) = tauijs_h3D(i,j,s) * (1 + mc_wedge(j,s))
%
% Intuition:
% - wedge applies at importer-sector level (j,s)
% - you can restrict it to EU only, and sectors steel/alum only
% ============================================================

% ---- Targets (edit to your current empirical objects)
target = [1.0084, 1.0458];  % [steel, aluminum] EU hats

% ---- Solve a single test wedge first (sanity check)
mc_test = [0.02; 0.02]; % 2% wedge on EU steel & alum (applies only to EU importer)
[P_EU_test, wi_test] = compute_prices_mc_wedge(mc_test(1), mc_test(2), ...
    N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
    sigma_s3D,tijs3D,tijs_p3D,Lijs3D,tauijs_h3D);

disp('--- Sanity check: 2% EU MC wedge ---');
disp('wage hats (EU, non-EU):'); disp(wi_test');
disp('EU sector price hats [steel, aluminum, otherNF]:'); disp(P_EU_test);

% ============================================================
% Step 1: Calibrate a SINGLE mc wedge (same for steel & alum)
% ============================================================
grid = 0.00:0.01:0.30;
target = [1.0084, 1.0458];

P_EU_grid = nan(length(grid), S);   % <-- IMPORTANT: 2D storage
loss = nan(length(grid), 1);

for g = 1:length(grid)
    m = grid(g);

    % get EU prices (row vector 1×S)
    P_tmp = compute_prices_mc_wedge(m, m, ...
        N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
        sigma_s3D,tijs3D,tijs_p3D,Lijs3D,tauijs_h3D);

    P_EU_grid(g,:) = P_tmp;                % <-- store row g
    loss(g) = sum((P_tmp(1:2) - target).^2); % <-- compare steel+al only
end
[~, idx] = min(loss);
best_m = grid(idx);
loss_best = loss(idx);

disp('--- Single-wedge calibration (m_steel=m_alum) ---')
disp(['best_m = ', num2str(best_m), '  loss = ', num2str(loss(idx))])
disp('matched [steel, aluminum]:')
disp(P_EU_grid(idx,1:2))
disp('target  [steel, aluminum]:')
disp(target)
% ============================================================
% Step 2: Sector-specific MC wedges (m_steel, m_alum)
% ============================================================

target = [1.0084, 1.0458];   % [steel, aluminum]

obj = @(m) local_loss_steel_al(m, target, ...
    N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
    sigma_s3D,tijs3D,tijs_p3D,Lijs3D,tauijs_h3D);

m0 = [0.05; 0.05];  % initial guess (steel, aluminum)

[m_hat, loss_val] = fminsearch(obj, m0, ...
    optimset('Display','iter','TolX',1e-10,'TolFun',1e-12));


m0 = [best_m; best_m];  % start from single-wedge best
[m_hat, loss_val] = fminsearch(obj, m0, optimset('Display','iter','TolX',1e-10,'TolFun',1e-12));

disp('--- Sector-specific MC wedge calibration ---')
disp('m_hat [steel, aluminum]:'); disp(m_hat(:)')
disp('loss:'); disp(loss_val)


% ============================================================
% Save results
% ============================================================
results = struct();
results.target = target;
results.betaEU = betaEU; results.betaNEU = betaNEU;
results.L_EU = L_EU; results.L_NEU = L_NEU;
results.sigma = sigma;

results.single_m = best_m;
results.single_loss = loss_best;
results.single_match = P_EU_grid(idx, 1:2);

results.m_hat = m_hat;
results.loss_val = loss_val;

save('mc_wedge_poc_results.mat','results');

disp('Saved: mc_wedge_poc_results.mat');

function L = local_loss_steel_al(m, target, ...
    N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
    sigma_s3D,tijs3D,tijs_p3D,Lijs3D,tauijs_h3D)

    % compute EU price hats for all sectors
    P_EU = compute_prices_mc_wedge(m(1), m(2), ...
        N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
        sigma_s3D,tijs3D,tijs_p3D,Lijs3D,tauijs_h3D);

    % compare only steel+aluminum
    L = sum((P_EU(1:2) - target).^2);
end
