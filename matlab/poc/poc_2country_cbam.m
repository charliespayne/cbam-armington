clear; clc;

% ---- Dimensions
N = 2;              % 1 = EU, 2 = non-EU
S = 2;              % 1 = steel, 2 = aluminum
mu = 1;

% ---- Baseline incomes (levels don't matter for PoC)
Yi = [1; 1];
Yi3D = repmat(reshape(Yi,[N 1 1]), [1 N S]);   % size N x N x S

% ---- No trade imbalances for PoC
Dj3D   = zeros(N,N,S);
Dj_h3D = zeros(N,N,S);

% ---- Baseline import shares lambda_{i,j,s} (sum over i = 1 for each j,s)
Lijs3D = zeros(N,N,S);

% Steel (s=1): EU buys 70% from EU, 30% from non-EU; non-EU buys 60% domestic
Lijs3D(:,1,1) = [0.70; 0.30];
Lijs3D(:,2,1) = [0.40; 0.60];

% Aluminum (s=2): EU buys 60% from EU, 40% from non-EU; non-EU buys 65% domestic
Lijs3D(:,1,2) = [0.60; 0.40];
Lijs3D(:,2,2) = [0.35; 0.65];

% ---- Sector expenditure weights beta_{j,s} (replicated across i)
betajs3D = zeros(N,N,S);
betaEU  = [0.5, 0.5];
betaNEU = [0.5, 0.5];

for j = 1:N
    if j==1
        betajs3D(:,j,1) = betaEU(1);
        betajs3D(:,j,2) = betaEU(2);
    else
        betajs3D(:,j,1) = betaNEU(1);
        betajs3D(:,j,2) = betaNEU(2);
    end
end

% ---- Elasticities: sigma = epsilon + 1
epsilon = [5, 5];
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

% ---- Solve for wage hats with fsolve
X0 = ones(N,1);

syst = @(X) DEK_TRF_SYSTEM_N1(X, N, S, mu, Yi3D, Dj3D, Dj_h3D, ...
                              betajs3D, sigma_s3D, tijs3D, tijs_p3D, ...
                              tauijs_h3D, Lijs3D);

opts = optimset('Display','iter','MaxIter',2000,'TolFun',1e-12,'TolX',1e-12);

[wi_h, fval] = fsolve(syst, X0, opts);

disp('max residual:'); disp(max(abs(fval)));
disp('wage hats (EU, non-EU):'); disp(wi_h);

% ---- Compute sector price index hats for each importer j and sector s
% P_hat(j,s) = [ sum_i lambda(i,j,s) * (phi(i,j,s)*w_i_hat)^(1-sigma_s) ]^(1/(1-sigma_s))

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

disp('EU sector price hats (Steel, Aluminum):');
disp(P_hat(1,:));

% =========================
% Step 6: Calibrate cbam_tau by matching Colmer targets
% =========================
target = [1.0084, 1.0458];      % [steel, aluminum] hats (edit if needed)
grid = 0.00:0.01:0.30;

P_EU = nan(length(grid), S);
loss = nan(length(grid), 1);

for g = 1:length(grid)
    cbam_tau = grid(g);

    % reset counterfactual tariffs
    tijs_p3D(:) = 0;
    tijs_p3D(2,1,1) = cbam_tau;   % steel
    tijs_p3D(2,1,2) = cbam_tau;   % aluminum

    % solve wages (same method you used before)
    obj = @(X) sum( DEK_TRF_SYSTEM_N1(X, N, S, mu, Yi3D, Dj3D, Dj_h3D, ...
                                      betajs3D, sigma_s3D, tijs3D, tijs_p3D, ...
                                      tauijs_h3D, Lijs3D ).^2 );

    [wi_h_tmp, fval_tmp] = fminsearch(obj, ones(N,1), optimset('Display','off','TolX',1e-10,'TolFun',1e-12));

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

    % loss vs targets
    loss(g) = sum((P_EU(g,:) - target).^2);
end

[~, idx] = min(loss);
best_tau = grid(idx);

disp('--- Calibration result ---')
disp(['Best cbam_tau: ', num2str(best_tau)])
disp('Matched EU price hats [steel, aluminum]:')
disp(P_EU(idx,:))
disp('Targets [steel, aluminum]:')
disp(target)

% =========================
% Step 7: Sector-specific CBAM wedges
% =========================

target = [1.0084, 1.0458];   % Colmer targets: [steel, aluminum]

obj2 = @(tau) ...
    sum( ...
        ( compute_prices(tau(1), tau(2), ...
            N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
            sigma_s3D,tijs3D,tauijs_h3D,Lijs3D) ...
        - target ).^2 );

% initial guess: start near previous result
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

save('cbam_poc_results.mat','results');