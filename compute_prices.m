function P_EU = compute_prices(tau_steel, tau_alum, ...
    N,S,mu,Yi3D,Dj3D,Dj_h3D,betajs3D, ...
    sigma_s3D,tijs3D,tauijs_h3D,Lijs3D)

tijs_p3D = zeros(N,N,S);
tijs_p3D(2,1,1) = tau_steel;
tijs_p3D(2,1,2) = tau_alum;

obj = @(X) sum( DEK_TRF_SYSTEM_N1(X, N, S, mu, Yi3D, Dj3D, Dj_h3D, ...
                                  betajs3D, sigma_s3D, tijs3D, tijs_p3D, ...
                                  tauijs_h3D, Lijs3D ).^2 );

wi_h = fminsearch(obj, ones(N,1), ...
        optimset('Display','off','TolX',1e-10,'TolFun',1e-12));

phi = tauijs_h3D .* (1+tijs_p3D) ./ (1+tijs3D);

P_EU = zeros(1,S);
for s = 1:S
    sig = sigma_s3D(1,1,s);
    tmp = 0;
    for i = 1:N
        tmp = tmp + Lijs3D(i,1,s) * (phi(i,1,s)*wi_h(i))^(1 - sig);
    end
    P_EU(s) = tmp^(1/(1 - sig));
end
end