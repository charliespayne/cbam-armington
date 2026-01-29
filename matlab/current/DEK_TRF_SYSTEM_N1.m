function [ERR]=DEK_TRF_SYSTEM_N1(X0, N ,S, mu, Yi3D, Dj3D, Dj_h3D, betajs3D, sigma_s3D, tijs3D, tijs_p3D, tauijs_h3D, Lijs3D)
% the current function returns the vector of differences between left- and righthand sides of the system WITH TARIFFS
% "_h" shands for "hat", "_p" -- for "prime", "3D" stands for "cubes"
% All inputs -- except wi_h (Nx1), yis_h (NxS) -- are assumed to be in NxNxS, where indices are ordered as (i,j,s)

% wi_yis_h is Nx(S+1) matrix where the last N rows are wi_h and the first N*S rows are yis_h
wi_h=abs(X0);	% Nx1, mod to avoid complex numbers...
%wi_h=X0;

% construct 3D cubes from 1D vectors
wi_h3D=repmat(wi_h,[1 N S]);
wj_h3D=permute(wi_h3D,[2 1 3]);
Yj3D=permute(Yi3D,[2 1 3]);
phiijs3D=tauijs_h3D.*(1+tijs_p3D)./(1+tijs3D);  % ratio of shipping costs (trans+tariffs): t'/t

% Compute the excess demand
AUX0=Lijs3D.*((phiijs3D.*wi_h3D).^(1-sigma_s3D));
AUX1=repmat(sum(AUX0,1),[N 1 1]);
AUX2=AUX0./AUX1;
AUX4=AUX2.*betajs3D.*tijs_p3D./(1+tijs_p3D);
AUX6=1-repmat(sum(sum(AUX4,3),1),[N 1 S]);  % denom of kappa_hat (also product of kappa*kappa_hat)
AUX8=AUX2.*betajs3D.*(wj_h3D.*Yj3D+Dj3D.*Dj_h3D.*(wj_h3D.^mu))./(AUX6.*(1+tijs_p3D));
ERR=sum(sum(AUX8,3),2)-wi_h.*Yi3D(:,1,1);
% --------------
ERR(N,1)=sum(Yi3D(:,1,1).*(wi_h-1));    % replace one excess equation with normalization,w^=w'/w=1, where w=sum_i(wi'*Li)/sum(wi*Li)
end


