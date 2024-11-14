function [P, varargout] = membraneIndent_pointIndent_const_u_d(d, N0, E ,h, a, nu, varargin)
%function for calculating the central deflection of a circular membrane
%subject to an point load including a finite pre-stress N0
%with clamped boundary edge as boundary condition (finite radial but no vertical displacement at the edge)  
%radial displacement at the edge is fixed as u0
%see boundary cond. (b), eq. (59), in Jin et al. (2017) Journal of the Mechanics and Physics of Solids (100) 85-102.
%solution here based on eqs.(89), (90) and (91)

%%INPUT:
%d                indentation depth
%N0 in N/m        pre-stress
%E in Pa          Young's modulus
%h in m           film thickness
%a in m           hole radius
%nu               Poisson ratio

%OUTPUT
%P in N           indentation Force

    P = zeros(size(d));
    beta_found = zeros(size(d));
    col = zeros(size(d));
    if nargout > 1
        minVals = zeros(size(d));        
        d_found = zeros(size(d));
        info = cell(length(d),1);
    end
    
    %dimensionless variables
    %xi = N0*(4*(pi*a)^2 / E / h ./ P.^2).^(1/3);    %pre-stress/load-ratio = n0/2/F^(2/3)   (1)
    %F = 4*a^2 .* P / (pi*E*h^4);                    %load                                   (2)
    n0 = 8*a^2*N0/E/h^3;                            %pre-stress (or residual stress)         (3)
    
    %xi_star = (3/4)^(2/3);
    d_0 = h*sqrt(n0/2);
    F_star = sqrt(n0^3/2) * 4/3*(3*(1-nu)/(1-3*nu))^(3/2);
    nu_star = 1/3;
    d_star = real( h*sqrt(n0)*sqrt(3/2)*sqrt((1-nu)/(1-3*nu)) );
    fullRange = (10.^linspace(-17,17,100))';
    
    %functions
    %C1>0 (d > d_star)
    F_fun_C1gt0 = @(beta) sqrt(n0^3/2) * (atan(beta) - beta./(1+beta.^2)) ./ ...
                    (beta.^2./(1+beta^2) - 2* (1-atan(beta)./beta)./(1-nu));
    d_fun_C1gt0 = @(beta) d_0*atan(beta) ./ sqrt(2/(nu-1)*((1+beta.^2*(1+nu)/2)./(1+beta.^2)-atan(beta)./beta));
    %C1<0 (d < d_star)
    F_fun_C1sm0 = @(beta) sqrt(n0^3/2) * (1-nu)^(3/2) * (beta .* sqrt(1+beta.^2) - log(sqrt(1+beta.^2)+beta)) ./ ...
                    (2-2*sqrt(1+beta.^2).*log(sqrt(1+beta.^2)+beta)./beta+(1-nu)*beta.^2).^(3/2);
    d_fun_C1sm0 = @(beta) d_0 * sqrt(1-nu) * log(sqrt(1+beta.^2)+beta)./ ...
        sqrt(2-2*sqrt(1+beta.^2).*log(sqrt(1+beta.^2)+beta)./beta+(1-nu)*beta.^2);
    
    
    denom_C1gt0 = @(x) x.^2./(1+x.^2) - 2 *(1-atan(x)./x)./(1-nu);
    beta_max_C1gt0 = fzero(denom_C1gt0, [1e-17, 1e17]);
    
    try
        denom_C1sm0 = @(x) 2-sqrt(1+x.^2).*log1p(2.*x.*sqrt(1+x.^2)+2*x.^2)./x+(1-nu)*x.^2;
        beta_min_C1sm0 = fzero(denom_C1sm0, [fminbnd(denom_C1sm0, 1e-17, 1e17), 1e17]);
    catch
        beta_min_C1sm0 =1e-17;
    end
    %Umsetzen so dass x->Inf ==> beta->beta_max
    beta_res_fun = @(x) beta_max_C1gt0./(1+beta_max_C1gt0./x) ;

    
    for ii = 1:length(d)
        bounds = [-17, 17];
        
        if  d(ii) <= 0
            F_fun = @(x) 0;
            col(ii) = 0;
        else
            if d(ii) < d_star
                F_fun = F_fun_C1gt0;
                d_minfun = @(x) d_fun_C1gt0(beta_res_fun(10.^x))-d(ii);
                col(ii) = 2;

            elseif d(ii) > d_star
                F_fun = F_fun_C1sm0;
                d_minfun = @(x) d_fun_C1sm0(10.^x)-d(ii);
                col(ii) = 3;
                bounds(1) = log10(beta_min_C1sm0);
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
                if  d(ii) < d_star
                    beta_found(ii) = beta_res_fun(beta_found(ii));
                end
            catch ME
                info{ii} = ME.message;
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