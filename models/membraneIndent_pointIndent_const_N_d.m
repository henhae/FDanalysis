function [P, varargout] = membraneIndent_pointIndent_const_N_d(d, N0, E ,h, a, varargin)
%function for calculating the central deflection of a circular membrane
%subject to an point load including a finite pre-stress N0
%with clamped boundary edge as boundary condition (finite radial but no vertical displacement at the edge)  
%pre-tension at edge is fixed as N0
%see boundary cond. (a), eq. (58), in Jin et al. (2017) Journal of the Mechanics and Physics of Solids (100) 85-102.
%solution here based on eqs.(87), (88) and (91)

%note: This solution does not depend on the Poisson ratio!

%%INPUT:
%d                indentation depth
%N0 in N/m        pre-stress
%E in Pa          Young's modulus
%h in m           film thickness
%a in m           hole radius

%OUTPUT
%P in N           indentation Force

%for d > d_max = d_star*pi/2, P = 0 is output!

    P = zeros(size(d));
    beta_found = zeros(size(d));
    if nargout > 1
        minVals = zeros(size(d));
        col = zeros(size(d));
        d_found = zeros(size(d));
        info = cell(length(d),1);
    end
    
    %dimensionless variables
    %xi = N0*(4*(pi*a)^2 / E / h ./ P.^2).^(1/3);    %pre-stress/load-ratio = n0/2/F^(2/3)   (1)
    %F = 4*a^2 .* P / (pi*E*h^4);                    %load                                   (2)
    n0 = 8*a^2*N0/E/h^3;                            %pre-stress (or residual stress)         (3)
    
    %xi_star = (3/4)^(2/3);
    d_star = h*sqrt(n0/2);
    fullRange = (10.^linspace(-17,17,100))';
    
    %functions
    %C1>0 (d > d_star)
    F_fun_C1gt0 = @(beta) (n0/2)^(3/2)*2*(1+beta.^2).^(3/2).*beta.^(-3) ...
                    *( atan(beta)-beta./(1+beta^2) );
    d_fun_C1gt0 = @(beta) d_star*atan(beta).*sqrt(1+beta.^2)./beta;
    %C1<0 (d < d_star)
    F_fun_C1sm0 = @(beta) (n0/2)^(3/2)*2 * beta^(-3) .* ...
                    (beta.*sqrt(1+beta.^2) - log(sqrt(1+beta.^2)+beta));
    %d_fun_C1sm0 = @(beta) d_star*log(sqrt(1+beta.^2)+beta)./beta;
    d_fun_C1sm0 = @(beta) d_star*log1p(2*beta.*(sqrt(1+beta.^2)+beta))./(2*beta);
    
    
    for ii = 1:length(d)
        bounds = [-17, 17];
        
        if d(ii) >  d_star*pi/2 || d(ii) <= 0
            F_fun = @(x) 0;
            col(ii) = 0;
        else
            if d(ii) > d_star && d(ii) < d_star*pi/2
                F_fun = F_fun_C1gt0;
                d_minfun = @(x) d_fun_C1gt0(10.^x)-d(ii);
                col(ii) = 2;

            elseif d(ii) < d_star
                F_fun = F_fun_C1sm0;
                d_minfun = @(x) d_fun_C1sm0(10.^x)-d(ii);
                col(ii) = 3;
            else %d(ii) > d_max = d_star*pi/2
                F_fun = @(x) 0;
                col(ii) = 0;
            end

            try
                if nargout > 1 
                    [beta_found(ii), minVals(ii), ~, info{ii}] = fzero(@(x) d_minfun(x), bounds); 
                else
                    beta_found(ii) = fzero(@(x) d_minfun(x), bounds); 
                end
                beta_found(ii) = 10.^beta_found(ii);
            catch ME
                info{ii} = [ME.message ' ' sprintf('d_fun(%.4e)=%.4e ', [10.^bounds; d_minfun(bounds)])];
            end
        end
        
        P(ii) = F_fun(beta_found(ii)) ./ (4*a^2) .* (pi*E*h^4);
        if nargout>1
            d_found(col == 2) = d_fun_C1gt0(beta_found(col == 2));
            d_found(col == 3) = d_fun_C1sm0(beta_found(col == 3));
            varargout{1} = table(d, d_found, P,col, beta_found, minVals./d, info, 'VariableNames', {'d', 'd_calc', 'P', 'col', 'beta', 'minVals_rel', 'info'});
        end
    end
end