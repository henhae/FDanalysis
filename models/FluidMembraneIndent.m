classdef FluidMembraneIndent
    %Functions describing the indentation of a fluid membrane:
    %Assumption: Membrane takes catenoid shape due to internal 

    properties

    end


    methods (Static)
        %spherical indenter

        function z = Spherical_z(r, d, r_ind, R_out)
            %shape of membrane: z(r)
            z = nan(size(r));

            b = FluidMembraneIndent.Spherical_b_from_d(d, r_ind, R_out);
            %max. radius of contact with indenter
            r_c = sqrt(r_ind).*sqrt(b);

            z(r<r_c) = -d +r_ind -sqrt(r_ind.^2-r(r<r_c).^2);
            z(r>=r_c) =  - b*acosh(R_out/b) + b*acosh(r(r>=r_c)/b);
        end

        function [b, varargout] = Spherical_b_from_d(d, r_ind, R_out)
            % determine min radius of catenoid from indentation depth d via
            % zero-point determination

            null_fun = @(b, r_ind, r_out,d_l) r_ind - sqrt(r_ind.^2 - r_ind.*b) ...
                + b.* (acosh(r_out./b) - acosh(sqrt(r_ind)./sqrt(b)) ) - d_l;
            
            b = zeros(size(d));

            if nargout > 1
                minVals = zeros(size(d));
                info = cell(size(d));
    
                for ii = 1:length(d)
                    try
                        d_minfun = @(b) null_fun(b, r_ind, R_out, d(ii));
                        [b(ii), minVals(ii), ~, info{ii}] = fzero(@(x) d_minfun(x), [eps r_ind-eps]); 
                    catch ME
                        b(ii) = NaN;
                        info{ii} = ME.message;
                    end
                end
                varargout = {minVals, info};
            else
                for ii = 1:length(d)
                    try
                        d_minfun = @(b) null_fun(b, r_ind, R_out, d(ii));
                        b(ii) = fzero(@(x) d_minfun(x), [eps r_ind-eps]); 
                    catch
                        b(ii) = NaN;
                    end
                end
            end
        end


        function d = Spherical_d_b(b, r_ind ,R_out)
            %Calculate indentation depth for given catenoid min radius
            r_c = sqrt(r_ind * b);
            d = r_ind - sqrt(r_ind.^2 - r_c.^2) ...
                + b.* (acosh(R_out/b) - acosh(r_c/b) );
        end


        function A = Spherical_A_b(b, r_ind, R_out)
            % membrane area as funct. of min. catenoid radius
            r_c = sqrt(r_ind * b);
            A = pi * (b.^2 .* (acosh(R_out./b) - acosh(r_c./b)) +...
                    R_out.*sqrt(R_out^2 - b.^2) - b.*sqrt(r_ind^2 - r_c.^2) + ...
                    2*(r_ind.^2 - r_ind .* sqrt(r_ind^2 - r_c.^2) )...
                    );           
        end

        function A = Spherical_A(d, r_ind, R_out)
            % membrane area as funct. of indentation depth
            b = FluidMembraneIndent.Spherical_b_from_d(d, r_ind, R_out);
            r_c = sqrt(r_ind * b);
            A = pi*( b.*d + R_out.*sqrt(R_out.^2 - b.^2) - r_c.^2 ...
                    + 2*(r_ind.^2 - r_ind .* sqrt(r_ind^2 - r_c.^2) )...
                    );
        end

        function F = Spherical_F (d, gamma0, r_ind, R_out)
            %force as function of indentation d
            b = FluidMembraneIndent.Spherical_b_from_d(d, r_ind, R_out);
            F = 2.*b.*pi * gamma0;
        end


        function F = Spherical_FE_b (b, Em,gamma0,r_ind,R_out)
            %force as function of catenoid min.radius b including area stretching
            A = FluidMembraneIndent.Spherical_A_b(b, r_ind, R_out);
            F = 2*b.*pi.*(gamma0 + Em.* (A/pi - R_out.^2)./R_out.^2);
        end

        function F = Spherical_FE (d, Em, gamma0, r_ind, R_out)
            %force as function of indentation d including area stretching
            b = FluidMembraneIndent.Spherical_b_from_d(d, r_ind, R_out);
            A = FluidMembraneIndent.Spherical_A_b(b, r_ind, R_out);
            F = 2*b.*pi.*(gamma0 + Em.* (A/pi - R_out.^2)./R_out.^2);
        end
    end





    methods (Static)
        %concical indenter

        function z = Conical_z(r, d, alpha, R_out)
            %shape of membrane: z(r)
            z = nan(size(r));

            b = FluidMembraneIndent.Conical_b_from_d(d, alpha, R_out);
            %max. radius of contact with indenter
            rk = b/cos(alpha);

            z(r<rk) = -d + r(r<rk)*tan(pi/2 - alpha);
            z(r>=rk) =  - b*acosh(R_out/b) + b*acosh(r(r>=rk)/b);
        end

        function [b, varargout] = Conical_b_from_d(d, alpha, R_out)
            % determine min radius of catenoid from indentation depth d via
            % zero-point determination
            null_fun = @(b, alpha_l, r_out,d_l) b .* (log((cos(alpha_l)./(sin(alpha_l)+1).*(r_out./b + sqrt((r_out./b).^2-1)))) ...
                       +1./sin(alpha_l) ) - d_l;
            b = zeros(size(d));

            if nargout > 1
                minVals = zeros(size(d));
                info = cell(size(d));
    
                for ii = 1:length(d)
                    try
                        d_minfun = @(b) null_fun(b, alpha, R_out, d(ii));
                        [b(ii), minVals(ii), ~, info{ii}] = fzero(@(x) d_minfun(x), [eps R_out-eps]); 
                    catch ME
                        b(ii) = NaN;
                        info{ii} = ME.message;
                    end
                end
                varargout = {minVals, info};
            else
                for ii = 1:length(d)
                    try
                        d_minfun = @(b) null_fun(b, alpha, R_out, d(ii));
                        b(ii) = fzero(@(x) d_minfun(x), [eps R_out-eps]); 
                    catch
                        b(ii) = NaN;
                    end
                end
            end
        end


        function d = Conical_d_b(b, alpha,R_out)
            %Calculate indentation depth for given catenoid min radius 
            r_c = b./cos(alpha);
            d = b .* (acosh(R_out./b) - acosh(r_c./b)) + b./sin(alpha);
        end


        function A = Conical_A_b(b, alpha, R_out)
            % membrane area as funct. of min. catenoid radius
            A = pi.* (b.^2.*(1./sin(alpha) + acosh(R_out./b) - acosh(1./cos(alpha)) )...
                    + R_out.*sqrt(R_out.^2-b.^2) );            
        end

        function A = Conical_A(d, alpha, R_out)
            % membrane area as funct. of indentation depth
            b = FluidMembraneIndent.Conical_b_from_d(d, alpha, R_out);
            A = pi*( b.*d + R_out.*sqrt(R_out.^2-b.^2) );
        end

        function F = Conical_F (d, gamma0, alpha, R_out)
            %force as function of indentation d
            b = FluidMembraneIndent.Conical_b_from_d(d, alpha, R_out);
            F = 2.*b.*pi * gamma0;
        end

        function F = Conical_FE_b (b, Em,gamma0,alpha,R_out)
            %force as function of catenoid min.radius b including area stretching
            A = FluidMembraneIndent.Conical_A_b(b, alpha, R_out);
            F = 2*pi.*b.*(gamma0 + Em .* (A/pi - R_out.^2)./R_out.^2);
        end

        function F = Conical_FE (d, Em,gamma0,alpha,R_out)
            %force as function of indentation d including area stretching
            b = FluidMembraneIndent.Conical_b_from_d(d, alpha, R_out);
            A = FluidMembraneIndent.Conical_A_b(b, alpha, R_out);
            F = 2*pi.*b.*(gamma0 + Em .* (A/pi - R_out.^2)./R_out.^2);
        end
    end

    methods (Static)
        %cylindrical indenter

        function z = Cylindrical_z(r, d, r_ind, R_out)
            %shape of membrane: z(r)

            b = FluidMembraneIndent.Cylindrical_b_from_d(d, r_ind, R_out);
            zb = -b .* acosh(R_out./b);
            
            z = zb + b.*acosh(r./b);
        end

        function [b, varargout] = Cylindrical_b_from_d(d, r_ind, R_out)
            % determine min radius of catenoid from indentation depth d via
            % zero-point determination
            %null_fun = @(b, r_in, r_out,d_l) b.* log( (r_in - sqrt(r_in^2 - b.^2))./(r_out - sqrt(r_out.^2 - b.^2)) ) - d_l;
            null_fun = @(b, r_in, r_out,d_l) b .* (acosh(r_out./b) - acosh(r_in./b)) - d_l;
            b = zeros(size(d));

            if nargout > 1
                minVals = zeros(size(d));
                info = cell(size(d));
    
                for ii = 1:length(d)
                    try
                        d_minfun = @(b) null_fun(b, r_ind, R_out, d(ii));
                        [b(ii), minVals(ii), ~, info{ii}] = fzero(@(x) d_minfun(x), [eps r_ind-eps]); 
                    catch ME
                        b(ii) = NaN;
                        info{ii} = ME.message;
                    end
                end
                varargout = {minVals, info};
            else
                for ii = 1:length(d)
                    try
                        d_minfun = @(b) null_fun(b, r_ind, R_out, d(ii));
                        b(ii) = fzero(@(x) d_minfun(x), [eps r_ind-eps]); 
                    catch
                        b(ii) = NaN;
                    end
                end
            end
        end


        function d = Cylindrical_d_b(b, r_ind, R_out)
            %Calculate indentation depth for given catenoid min radius 
            d = b.* (acosh(R_out./b) - acosh(r_ind./b));
        end


        function A = Cylindrical_A_b(b, r_ind, R_out)
            % membrane area as funct. of min. catenoid radius
            A = pi*(r_ind.^2 + b.^2.* (acosh(R_out./b) - acosh(r_ind./b)) ...
                + R_out.*sqrt(R_out.^2-b.^2) - r_ind.*sqrt(r_ind.^2-b.^2) );
        end

        function A = Cylindrical_A(d, r_ind, R_out)
            % membrane area as funct. of indentation depth
            b = FluidMembraneIndent.Cylindrical_b_from_d(d, r_ind, R_out);
            %A = pi*(r_ind.^2 + b.*d + R_out.*sqrt(R_out.^2-b.^2) - r_ind.*sqrt(r_ind.^2-b.^2));
            A = pi*(r_ind.^2 + b.^2.* (acosh(R_out./b) - acosh(r_ind./b)) ...
                + R_out.*sqrt(R_out.^2-b.^2) - r_ind.*sqrt(r_ind.^2-b.^2) );
        end

        function F = Cylindrical_F (d, gamma0, r_ind, R_out)
            %force as function of indentation d
            b = FluidMembraneIndent.Cylindrical_b_from_d(d, r_ind, R_out);
            F = 2.*b.*pi * gamma0;
        end


        function F = Cylindrical_FE_b (b, Em, gamma0, r_ind, R_out)
            %force as function of catenoid min.radius b including area stretching
            A = FluidMembraneIndent.Cylindrical_A_b(b, r_ind, R_out);
            F = 2*pi.*b.*(gamma0 + Em .* (A/pi - R_out.^2)./R_out.^2);
        end

        function F = Cylindrical_FE (d, Em, gamma0, r_ind ,R_out)
            %force as function of indentation d including area stretching
            b = FluidMembraneIndent.Cylindrical_b_from_d(d, r_ind, R_out);
            A = FluidMembraneIndent.Cylindrical_A_b(b, r_ind, R_out);
            F = 2*pi.*b.*(gamma0 + Em .* (A/pi - R_out.^2)./R_out.^2);
        end
    end

end
