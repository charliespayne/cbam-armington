function [P_EU, wi_h] = compute_prices_mc_wedge(m_steel, m_alum, ...
    N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
    sigma_s3D,tijs3D,tijs_p3D,Lijs3D,tauijs_h3D)

% Ensure shared core functions are on path.
thisDir = fileparts(mfilename('fullpath'));               % .../matlab/experiments/mc_wedge_calibration
coreDir = fullfile(fileparts(fileparts(thisDir)), 'core'); % .../matlab/core
addpath(coreDir);

% ============================================================
% Compute EU price hats under an importer-sector MC wedge:
% delivered_hat(i,j,s) = tauijs_h3D(i,j,s) * (1 + mc_wedge(j,s))
%
% Implementation:
% - Apply wedge ONLY to EU importer (j=1)
% - Apply wedge only to s=1 (steel) and s=2 (aluminum)
% - Keep other sectors unshocked (s=3) for now
% ============================================================

% Build exporter-side MC wedge by exporter-sector: mc_i(i,s)
% Interpretation: EU producers' marginal costs rise in steel/aluminum.
mc_i = zeros(N,S);
mc_i(1,1) = m_steel;  % EU exporter steel
mc_i(1,2) = m_alum;   % EU exporter aluminum
% mc_i(1,3) = 0;      % otherNF unchanged (default)

% Start from baseline iceberg hats
deliv_hat = tauijs_h3D;

% Apply wedge ONLY to nonEU exporter (i=2) into EU importer (j=1)
% and only for steel/aluminum unless you want s=3 too.
% Apply wedge ONLY to nonEU exporter (i=2) into EU importer (j=1)
deliv_hat(2,1,1) = deliv_hat(2,1,1) * (1 + m_steel);  % steel
deliv_hat(2,1,2) = deliv_hat(2,1,2) * (1 + m_alum);   % aluminum
% deliv_hat(2,1,3) = deliv_hat(2,1,3) * (1 + mc(1,3)); % otherNF if desired

disp('deliv_hat multipliers (i rows, j cols) for s=1:'); disp(deliv_hat(:,:,1));
disp('deliv_hat multipliers (i rows, j cols) for s=2:'); disp(deliv_hat(:,:,2));

% Solve equilibrium wage hats given delivered_hat (feeds into DEK system as tau hats)
% NOTE: DEK_TRF_SYSTEM_N1 expects tauijs_h3D; we pass deliv_hat.
X0 = ones(N,1);
syst = @(X) DEK_TRF_SYSTEM_N1(X, N, S, mu, Yi3D, Dj3D, Dj_h3D, ...
                              betajs3D, sigma_s3D, tijs3D, tijs_p3D, ...
                              deliv_hat, Lijs3D);

% If you have Optimization Toolbox, fsolve is best.
opts = optimset('Display','off','MaxIter',2000,'TolFun',1e-12,'TolX',1e-12);
[wi_h, fval] = fsolve(syst, X0, opts);

% If you ever want robustness without fsolve, swap to fminsearch objective:
% obj = @(X) sum(syst(X).^2);
% wi_h = fminsearch(obj, X0, optimset('Display','off','TolX',1e-10,'TolFun',1e-12));

% Compute EU sector price hats for s=1..S
% P_hat(j,s) = [ sum_i lambda(i,j,s) * (phi(i,j,s)*w_i_hat)^(1-sigma_s) ]^(1/(1-sigma_s))
% Here: phi includes delivered_hat and tariffs (tariffs are zero in this PoC)
phi = deliv_hat .* (1+tijs_p3D) ./ (1+tijs3D);

P_hat = zeros(N,S);
for j = 1:N
    for s = 1:S
        sig = sigma_s3D(1,1,s); % constant in your PoC
        tmp = 0;
        for i = 1:N
            tmp = tmp + Lijs3D(i,j,s) * (phi(i,j,s)*wi_h(i))^(1 - sig);
        end
        P_hat(j,s) = tmp^(1/(1 - sig));
    end
end

% Return EU importer (j=1)
P_EU = P_hat(1,:);
P_EU = P_EU(:)'; % row

% Also return wages
% wi_h returned already
end
