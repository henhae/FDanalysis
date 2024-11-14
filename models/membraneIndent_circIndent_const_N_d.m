function [P, varargout] = membraneIndent_circIndent_const_N_d(d, N0, E ,h, a, R, varargin)
%function for calculating the central deflection of a circular membrane
%subject to a load P by a spherical indenter including a finite pre-stress N0
%with clamped boundary edge as boundary condition (finite radial but no vertical displacement at the edge)  
%pre-tension at edge is fixed as N0
%see boundary cond. (a), eq. (58), in Jin et al. (2017) Journal of the Mechanics and Physics of Solids (100) 85-102.
%solution here based on eqs.(75-77), (79-80) or (92-93)

%note: This solution does not depend on the Poisson ratio!

%%INPUT:
%d                indentation depth
%N0 in N/m        pre-stress
%E in Pa          Young's modulus
%h in m           film thickness
%a in m           hole radius
%R in m           indenter radius

%OUTPUT
%P in N           indentation Force

if nargin > 6
    if nargin > 7
        error('Too many inputs variables.');
    end
    if islogical(varargin{1})
        diagnoseMode = varargin{1};
    else
        error('Input #7 (enable diagnose mode) must be true/false.');
    end
else
    diagnoseMode = false;
end

F = zeros(size(d));
zeta = zeros(size(d));      % = (c/a)^2  ,c: radius of membrane contact line at indenter
C1 = zeros(size(d));
C2 = zeros(size(d));
C2_ub = zeros(size(d));     %upper limit for C2 (dep. on zeta)
zetacol = zeros(size(d));
d_calc = zeros(size(d));
alphas_found = zeros(size(d));
betas_found = zeros(size(d));

%dimensionless variables
%xi = N0*(4*(pi*a)^2 / E / h ./ P.^2).^(1/3);    %pre-stress/load-ratio = n0/2/F^(2/3)   (1)
%F = 4*a^2 .* P / (pi*E*h^4);                    %load                                   (2)
lambda = h*R/a^2;                               %indenter Radius                        (3)
n0 = 8*a^2*N0/E/h^3;                            %pre-stress (or residual stress)        (4)
gamma = lambda*sqrt(2*n0);                      %= sqrt(N0/Eh) * 4 R/a                  (5)

%xi_star = 3/4+(1-3*sqrt(2)/4)*sqrt(2*F*lambda^3); %                                     (6)

%with (1)&(6) and xi_star = (xi(C1 = 0))^(3/2) = (n0/2)^(3/2)./F_star
% ==> (n0/2)^(3/2)./F_star = 3/4+(1-3*sqrt(2)/4)*sqrt(2*F_star*lambda^3)
F_C1eq0 = fzero(@(x) x.*(3/4-(3/2-sqrt(2))*sqrt(x*lambda^3))-(n0/2)^(3/2), [4/3*(n0/2)^(3/2) 1./(4*lambda^3*(1.5-sqrt(2)))]); %eq. (70) in (71)
d_C1eq0 = h/(2*lambda)*sqrt(2*F_C1eq0*lambda^3) * ( (3./sqrt(2*F_C1eq0*lambda^3)+4-3*sqrt(2))^(1/3)+sqrt(2)-2);

%F_max calculation: max. F from C1 > 0 branch:
%i.e. from (75) for beta->Inf / theta_m -> pi/2 (since beta > alpha...)
%   alpha = tan(theta_n)
if gamma < 1e-4
    alphaMaxC1gt0 = sqrt(gamma*pi/4);
else
    alphaMaxC1gt0 = fzero(@(x) x./(sqrt(2+x.^2)+1)+1/2./x + (1+x.^2)./(2*x.^2).*(pi/2 - atan(x)) -1/gamma, sqrt(gamma*pi/4));
end
F_Max = n0/lambda*1./(1+1./alphaMaxC1gt0.^2);
d_Max = h*sqrt(n0/2)*(pi/2-atan(alphaMaxC1gt0)+alphaMaxC1gt0./(sqrt(2+alphaMaxC1gt0)+1));

if any(d>d_Max)
 %   error('Values for d larger than possible maximum of %.5g m provided (for given N0 = %.5g N/m and E = %.5g Pa)', d_Max, N0, E);
 % output P = 0 for these values (see second last line)
end


%branchIndicator = sign((xi).^(3/2) - xi_star);
branchIndicator = sign(d - d_C1eq0);
branchIndicator(d>d_Max | d <=0 ) = 0;
C1gt0BranchIdxs = find(branchIndicator == 1);
C1sm0BranchIdxs = find(branchIndicator == -1);


%functions
%minimization functions
%C1>0
        %%% Eq.(75) or (92), yet with variable redefinition:
        %alpha = tan(theta_n), beta = tan(theta_m), thus alpha(beta) have
        %range (-Inf; Inf) (instead of (0; pi/2) for theta, which gives
        %problems when approaching pi/2
        % y = tan(x) ==> sin(x) = tan(x)/sqrt(1+(tan(x))^2) = y/sqrt(1+y^2), cos(x) = 1/sqrt(1+(tan(x))^2) = 1/sqrt(1+y^2)

           
alphabetaMinFuncC1gt0 = @(beta, alpha) beta./(sqrt(1+beta.^2)) /gamma ...
                        + (1+alpha.^2)./(2.*alpha.^2) .* (beta./(1+beta.^2) - atan(beta)) ...
                        + (1+alpha.^2)./(2.*alpha.^2) .* atan(alpha)...
                        - 1./(2.*alpha) - alpha ./(sqrt(2+alpha.^2)+1);
                    
            
alphabetaLogMinFuncC1gt0 = @(beta, alpha) alphabetaMinFuncC1gt0(10.^(beta), 10.^(alpha));

%C1<0
               %%% Eq.(76) or (93), yet with variable redefinition:
               %alpha = cot(theta_n), beta = cot(theta_m), 
               % y = cot(x) ==> sin(x) = 1/sqrt(1+(cot(x))^2) = 1/sqrt(1+y^2), cos(x) = cot(x)/sqrt(1+(cot(x))^2) = y/sqrt(1+y^2)
alphabetaMinFuncC1sm0 = @(beta,alpha)  alpha./(sqrt(2+alpha.^2)+sqrt(1+alpha.^2)) ...
                    + 0.5*beta.* alpha.^(-2).*(sqrt(1+beta.^2)) ...
                    - 0.5*(sqrt(1+alpha.^2))./alpha ...
                    + log((sqrt(1+alpha.^2)+alpha)./(sqrt(1+beta.^2)+beta) ) .* 0.5 .* alpha.^(-2) ...
                    - beta./lambda./sqrt(2*n0);
                %using log(alpha) in fzero, the zero positions are more precisely found.
alphabetaLogMinFuncC1sm0 = @(beta, alpha) alphabetaMinFuncC1sm0(10.^(beta), 10.^(alpha));

%F functions
%C1>0
F_fun_alphbet_C1gt0 = @(beta,alpha) n0./lambda .* (1+1./beta.^2)./(1+1./alpha.^2);
%C1<0
F_fun_alphbet_C1sm0 = @(beta,alpha) n0./lambda .* (alpha./beta).^2;

%d functions
%C1>0
d_fun_alphbet_C1gt0 = @(beta,alpha) h.*sqrt(n0./2) .* sqrt(1+beta.^2)./beta .* ...
                ( (atan(beta)-atan(alpha)) + alpha ./ (sqrt(2+alpha.^2)+1) );
%C1<0
d_fun_alphbet_C1sm0 = @(beta,alpha) h.*sqrt(n0./2).*alpha./beta .* ...
                     (1./alpha.*log((sqrt(1+beta.^2)+beta)./(sqrt(1+alpha.^2)+alpha))+...
                     1./(sqrt(2+alpha.^2) + sqrt(1+alpha.^2))  );


%%% get rough F_calc(alpha) and determine interval [alpha_min, alpha_max] for [min(F), max(F)]
% ==> smaller search interval for alpha ==> faster alpha(F)

full17Range = 10.^(linspace(-17, 17, 60)');

% C1>0
if ~isempty(C1gt0BranchIdxs)

    alpha_res_fun = @(x) alphaMaxC1gt0./(1+1./(alphaMaxC1gt0.*x)) ;
    alphaC1gt0Range = alpha_res_fun(full17Range);
    
    betaFull_C1gt0 = zeros(size(full17Range));
    minFunVal = nan(size(full17Range));
    fail1reason = cell(size(full17Range));
     
    bounds = ones(size(full17Range)) * [eps^4 1e34];
    %beta min follows from d > 0:
    %alpha should be always smaller than beta. Solutions with alpha > beta give nonsense F and d. (i.e. d<0)
    %==> lower bound for beta:
    bounds(:,1) = tan(atan(alphaC1gt0Range) - alphaC1gt0Range./(sqrt(2+alphaC1gt0Range)+1) );  
    for iii = 1:length(full17Range)        
        ab_fun = @(logbeta) alphabetaLogMinFuncC1gt0(logbeta, log10(alphaC1gt0Range(iii)));
        if bounds(iii,1) > bounds(iii,2)
            betaFull_C1gt0(iii) = NaN;
        else
            try
                [betaFull_C1gt0(iii), minFunVal(iii)] = fzero(ab_fun, log10(bounds(iii,:)));
                betaFull_C1gt0(iii) = 10.^(betaFull_C1gt0(iii));
            catch ME
                fail1reason{iii} = ME.message;
            end
        end
            
    end
    
    dRange_C1gt0 = d_fun_alphbet_C1gt0(betaFull_C1gt0, alphaC1gt0Range);
    [dRange_C1gt0_sorted, dR_Idxs_sort] = sort(dRange_C1gt0);
    minIdx = find(dRange_C1gt0_sorted>d_C1eq0 & minFunVal(dR_Idxs_sort) < 1e-10, 1)-1;
    %minAlpha_C1gt = alphaRange(FR_Idxs_sort(minIdx));
    minXs_C1gt = full17Range(dR_Idxs_sort(minIdx));
end 



%%%%%  C1<0  %%%%%%%%
if ~isempty(C1sm0BranchIdxs)
    betaFull_C1sm0 = zeros(size(full17Range));
    minFunVal = nan(size(full17Range));
    for iii = 1:length(full17Range)
        bounds_C1sm0 = [1e-17 1e17];
        ab_fun = @(logbeta) alphabetaLogMinFuncC1sm0(logbeta, log10(full17Range(iii)));
        %alpha should be always smaller than beta. Solutions with alpha > beta give nonsense F and d.
        bounds_C1sm0(1) = full17Range(iii);
        %for very large betas, beta -> 2*alpha^2/gamma;
        bounds_C1sm0(2) = max([1e17 4*bounds_C1sm0(1)^2/gamma]);
        
        try
            [betaFull_C1sm0(iii), minFunVal(iii)] = fzero(ab_fun, log10(bounds_C1sm0));
            betaFull_C1sm0(iii) = 10.^(betaFull_C1sm0(iii));
        catch ME
            betaFull_C1sm0(iii) = NaN;
        end
            
    end    
    dRange_C1sm0 = d_fun_alphbet_C1sm0(betaFull_C1sm0, full17Range);
    %[~, d_max_C1sm0_Idx] = max(dRange_C1sm0);
    isvalidalpha_C1sm0 = (full17Range ~= betaFull_C1sm0 & ~isnan(betaFull_C1sm0));
    alphaRange_C1sm0 = full17Range(isvalidalpha_C1sm0);
    dRange_C1sm0 = dRange_C1sm0(isvalidalpha_C1sm0);
    
    %idxRange_C1sm0 = find(dRange_C1sm0 > min(d) & dRange_C1sm0 < max(d(d<d_C1eq0)));
    %idxRange_C1sm0(idxRange_C1sm0 < d_max_C1sm0_Idx) = [];
    
    alpha_of_dMin_C1sm0 = alphaRange_C1sm0( dRange_C1sm0 == max( dRange_C1sm0(dRange_C1sm0<min(d(d>0))) )  );
    alpha_of_dMax_C1sm0 = alphaRange_C1sm0( dRange_C1sm0 == min( dRange_C1sm0(dRange_C1sm0>min([max(d),d_C1eq0])) ) );
    minmaxAlpha_C1sm0 = sort([alpha_of_dMin_C1sm0 alpha_of_dMax_C1sm0]);
end
    
    
%%%% calc d from given F: main part  %%%%%%
if diagnoseMode || nargout == 2
    if size(F,1) == 1
        d_resh = reshape(d, length(d), 1);
    else
        d_resh = d;
    end
    abCalcDataViaFunc = array2table(zeros(length(d), 5), 'VariableNames', {'alpha', 'beta', 'thetan', 'thetam', 'exitflag'});
    abCalcDataViaFunc.d = d;
    abCalcDataViaFunc.info = cell(length(d),1);
end

    %C1>0
if ~isempty(C1gt0BranchIdxs)
    betaLowerBoundFromAlpha_C1gt0 = @(alpha) tan(atan(alpha) - alpha./(sqrt(2+alpha)+1));
    minmaxXs_C1gt0= sort([minXs_C1gt ; 1e17] );
    betaFromX_C1gt0 = @(X) 10.^fzero(@(logbeta) alphabetaLogMinFuncC1gt0(logbeta,log10(alpha_res_fun(X))), [log10(betaLowerBoundFromAlpha_C1gt0(alpha_res_fun(X))), 17]);
    d_fromX_C1gt0 = @(X) arrayfun(@(scalar_X) d_fun_alphbet_C1gt0(betaFromX_C1gt0(scalar_X), alpha_res_fun(scalar_X)),X);

    
    if diagnoseMode || nargout == 2   
        [alphas_found(C1gt0BranchIdxs), betas_found(C1gt0BranchIdxs), d_calc(C1gt0BranchIdxs), exitflag, Info] = getAlphasFromDs_C1gt0(d_resh(C1gt0BranchIdxs));
        abCalcDataViaFunc.exitflag(C1gt0BranchIdxs) = exitflag;
        abCalcDataViaFunc.info (C1gt0BranchIdxs) = Info;
    else
        [alphas_found(C1gt0BranchIdxs), betas_found(C1gt0BranchIdxs)] = getAlphasFromDs_C1gt0(d(C1gt0BranchIdxs));
    end
    
    F(C1gt0BranchIdxs) = F_fun_alphbet_C1gt0(betas_found(C1gt0BranchIdxs), alphas_found(C1gt0BranchIdxs));
    zeta(C1gt0BranchIdxs) = lambda*sqrt(2*n0)* alphas_found(C1gt0BranchIdxs)./(sqrt(2+alphas_found(C1gt0BranchIdxs).^2)+1).*sqrt(1+1./(betas_found(C1gt0BranchIdxs).^2));
    C2_helpfun_alpha_C1gt0 = @(x) 2*atan(x) - x./(1+x.^2);
    C1(C1gt0BranchIdxs) = F(C1gt0BranchIdxs)/lambda.*(alphas_found(C1gt0BranchIdxs).^2)./(1+alphas_found(C1gt0BranchIdxs).^2);
    C2(C1gt0BranchIdxs) = (zeta(C1gt0BranchIdxs).*C2_helpfun_alpha_C1gt0(betas_found(C1gt0BranchIdxs)) - C2_helpfun_alpha_C1gt0(alphas_found(C1gt0BranchIdxs)))...
                                                ./(C2_helpfun_alpha_C1gt0(alphas_found(C1gt0BranchIdxs))-C2_helpfun_alpha_C1gt0(betas_found(C1gt0BranchIdxs)));
    C2_ub(C1gt0BranchIdxs) = zeta(C1gt0BranchIdxs).*( (1+alphas_found(C1gt0BranchIdxs).^2)./(alphas_found(C1gt0BranchIdxs).^3).*C2_helpfun_alpha_C1gt0(alphas_found(C1gt0BranchIdxs)) -1);
end    
    
    
    function [alphas, varargout] = getAlphasFromDs_C1gt0(expDs)
        alphas = zeros(size(expDs));
        Xs = zeros(size(expDs));
        betas = zeros(size(expDs));
        dcalcs = zeros(size(expDs));
        exitfl = zeros(size(expDs));
        outpCell = cell(size(expDs));
        for in = 1:length(expDs)
            try
                %Das hier macht schon alles: Alphas zu den Fs rausfinden,
                %die näher an den F_exp dran sind als 1e-6. Leider werden
                %keine betas ausgegeben.
                [Xs(in), dcalcs(in), exitfl(in), outpCell{in}] = fzero(@(y) d_fromX_C1gt0(y)./(expDs(in))-1, minmaxXs_C1gt0, struct('TolX', 1e-8));
                alphas(in) = alpha_res_fun(Xs(in));
                dcalcs(in) = (dcalcs(in)+1)*expDs(in);
                betas(in) = betaFromX_C1gt0(Xs(in)); 
                d_check = d_fun_alphbet_C1gt0(betas(in), alphas(in));
                %Check, dass das auch wirklich passt.
                if abs(d_check - expDs(in))/expDs(in) > 1e-5
                    error('Unknown error.')
                end
            catch ME
                alphas(in) = NaN;
                betas(in) = NaN;
                dcalcs(in) = NaN;
                outpCell{in} = ME.message;
            end
            
        end
        varargout = {betas dcalcs exitfl outpCell};
    end
    
    
    
    %C_1 < 0 branch
if ~isempty(C1sm0BranchIdxs)    
    betaFromAlpha_C1sm0 = @(alpha) 10.^fzero(@(logbeta) alphabetaLogMinFuncC1sm0(logbeta,log10(alpha)), [log10(alpha), max(17,log10(4*alpha.^2/gamma))]);
    d_fromAlpha_C1sm0 = @(x) arrayfun(@(y) d_fun_alphbet_C1sm0(betaFromAlpha_C1sm0(y), y),x);
    
    if diagnoseMode || nargout == 2
        [alphas_found(C1sm0BranchIdxs), betas_found(C1sm0BranchIdxs), d_calc(C1sm0BranchIdxs), exitflag, Info] = getAlphasFromDs_C1sm0(d_resh(C1sm0BranchIdxs));
        abCalcDataViaFunc.exitflag(C1sm0BranchIdxs) = exitflag;
        abCalcDataViaFunc.info(C1sm0BranchIdxs) = Info;
    else
        [alphas_found(C1sm0BranchIdxs), betas_found(C1sm0BranchIdxs)] = getAlphasFromDs_C1sm0(d(C1sm0BranchIdxs));
    end
    F(C1sm0BranchIdxs) = F_fun_alphbet_C1sm0(betas_found(C1sm0BranchIdxs), alphas_found(C1sm0BranchIdxs));
    zeta(C1sm0BranchIdxs) = lambda*sqrt(2*n0)* alphas_found(C1sm0BranchIdxs)./(betas_found(C1sm0BranchIdxs))./(sqrt(2+alphas_found(C1sm0BranchIdxs).^2)+sqrt(1+alphas_found(C1sm0BranchIdxs).^2));
    C1(C1sm0BranchIdxs) = -F(C1sm0BranchIdxs)/lambda.*(alphas_found(C1sm0BranchIdxs).^2);
    C2_helpfun_alpha_C1sm0 = @(x) x.*sqrt(1+x.^2) - log(sqrt(1+x.^2)+x);
    C2(C1sm0BranchIdxs) = (zeta(C1sm0BranchIdxs).*C2_helpfun_alpha_C1sm0(betas_found(C1sm0BranchIdxs)) - C2_helpfun_alpha_C1sm0(alphas_found(C1sm0BranchIdxs)))...
                                                ./(C2_helpfun_alpha_C1sm0(alphas_found(C1sm0BranchIdxs))-C2_helpfun_alpha_C1sm0(betas_found(C1sm0BranchIdxs)));
	C2_ub(C1sm0BranchIdxs) = zeta(C1sm0BranchIdxs).*( 2*sqrt(1+alphas_found(C1sm0BranchIdxs).^2)./(alphas_found(C1sm0BranchIdxs).^3).*C2_helpfun_alpha_C1sm0(alphas_found(C1sm0BranchIdxs)) -1);
end

    function [alphas, varargout] = getAlphasFromDs_C1sm0(expDs)
        alphas = zeros(size(expDs));
        betas = zeros(size(expDs));
        dcalcs = zeros(size(expDs));
        exitfl = zeros(size(expDs));
        outpCell = cell(size(expDs));
        for in = 1:length(expDs)
            try
                %Das hier macht schon alles: Alphas zu den Fs rausfinden,
                %die näher an den F_exp dran sind als 1e-8. Leider werden
                %keine betas ausgegeben.
                [alphas(in), dcalcs(in), exitfl(in), outpCell{in}] = fzero(@(y) d_fromAlpha_C1sm0(y)./(expDs(in))-1, minmaxAlpha_C1sm0, struct('TolX', 1e-8));
                dcalcs(in) = (dcalcs(in)+1)*expDs(in);
                betas(in) = betaFromAlpha_C1sm0(alphas(in));
                d_check = d_fun_alphbet_C1sm0(betas(in), alphas(in));
                %Check, dass das auch wirklich passt.
                if abs(d_check - expDs(in))/expDs(in) > 1e-5
                    error('Unknown error.')
                end
            catch ME
                alphas(in) = NaN;
                betas(in) = NaN;
                dcalcs(in) = NaN;
                outpCell{in} = ME.message;
            end
            
        end
        varargout = {betas dcalcs exitfl outpCell};
    end

    P = F ./ (4*a^2) .* (pi*E*h^4);

    zetacol(C2 < -zeta) = zetacol(C2 < -zeta) + 1; %C2 too low
    zetacol(C2 > C2_ub) = zetacol(C2 > C2_ub) + 2; %C2 too high
    zetacol(isnan(C2)) = zetacol(isnan(C2)) + 3;

    if diagnoseMode || nargout == 2
        abCalcDataViaFunc.alpha = alphas_found;
        abCalcDataViaFunc.beta = betas_found;
        abCalcDataViaFunc.thetan(C1gt0BranchIdxs) = atan(alphas_found(C1gt0BranchIdxs));
        abCalcDataViaFunc.thetam(C1gt0BranchIdxs) = atan(betas_found(C1gt0BranchIdxs));
        abCalcDataViaFunc.thetan(C1sm0BranchIdxs) = acot(alphas_found(C1sm0BranchIdxs));
        abCalcDataViaFunc.thetam(C1sm0BranchIdxs) = acot(betas_found(C1sm0BranchIdxs));
        
        abCalcDataViaFunc.d_calc = d_calc;
        abCalcDataViaFunc.P = P;
        abCalcDataViaFunc.zeta = zeta;
        abCalcDataViaFunc.C1 = C1;
        abCalcDataViaFunc.C2 = C2;
        abCalcDataViaFunc.C2_ub = C2_ub;
        abCalcDataViaFunc.C1branch = branchIndicator;
        abCalcDataViaFunc.zetacheck = zetacol;
        %abCalcDataViaFunc.F_max = ones(size(alphas_found))*d_Max;
        abCalcDataViaFunc.F_max = ones(size(alphas_found))*F_Max;
        abCalcDataViaFunc.d_max = ones(size(alphas_found))*d_Max;
        abCalcDataViaFunc.P_max = ones(size(alphas_found))*F_Max * (pi*E*h^4) / (4*a^2);
        
        if nargout > 1
            varargout{1} = abCalcDataViaFunc;
        end
        
        if diagnoseMode        
            figure(120);
            clf;
            plot(alphas_found,d, 'k', alphas_found(C1sm0BranchIdxs), d_calc(C1sm0BranchIdxs), 'm-o', alphas_found(C1gt0BranchIdxs), d_calc(C1gt0BranchIdxs), 'r-o');
            legend({'d input', 'C1 < 0 part', 'C1 > 0 part'});
            xlabel('\it alpha')
            ylabel('\it d \rm / m')
            figure(121);
            plot(F,C2, 'r.-', F(C1gt0BranchIdxs),C2(C1gt0BranchIdxs), 'ro', F, C2_ub, 'g-', F, -zeta, 'b-');
            xlabel('\it F \rm / normalized');
            ylabel('C2');
            legend({'C2(where C1 < 0)', 'C2(where C1 > 0)', 'C2 upper bound', 'C2 lower bound'});
        end
    end
    
    P(zetacol>0) = 0;
    P(d>d_Max) = 0;
end
