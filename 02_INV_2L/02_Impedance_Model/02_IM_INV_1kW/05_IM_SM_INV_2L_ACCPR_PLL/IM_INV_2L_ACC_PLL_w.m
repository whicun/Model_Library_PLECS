%% Numeric Calculation of Inverter Impedance Model 
% ########################################################################
% numeric calculation of impedance/admitance at a given frequency
% Input:
%       - [obj] grid parameter
%       - [obj] inverter parameter
%       - [obj] control parameter 
%       - [num] calculation frequency [rad/s]
% Output:
%       - [matrix] impedance/admitance matrix at a given frequency
% Consider:
%       - ACC
%       - PLL
%       - AD
%       - VFF
% Establishment: 18.03.2019, Zhiqing Yang, PGS, RWTH Aachen
% ########################################################################

function [Z_inv_w, Y_inv_w, Z_pcc_w, Y_pcc_w, Z_g_w, Y_g_w] = IM_INV_2L_ACC_PLL_w(Grid,Inv,Ctrl,w)
%% Calculation of the Steady-State Values
Inv.OP.I_L1_d = Ctrl.I_ref_d;
Inv.OP.I_L1_q = Ctrl.I_ref_q;
Inv.OP.V_C_d = sqrt((Grid.V_amp)^2-(Inv.OP.I_L1_q*(Inv.Filter.R2+Grid.Rg)+Inv.OP.I_L1_d*Grid.wg*(Inv.Filter.L2+Grid.Lg))^2)...
               +Inv.OP.I_L1_d*(Inv.Filter.R2+Grid.Rg)+Inv.OP.I_L1_q*Grid.wg*(Inv.Filter.L2+Grid.Lg);
Inv.OP.V_C_q = 0;
Inv.OP.I_C_d = Inv.OP.V_C_q*Grid.wg*Inv.Filter.C;
Inv.OP.I_C_q = -Inv.OP.V_C_d*Grid.wg*Inv.Filter.C;
Inv.OP.V_inv_d = Inv.OP.V_C_d+Inv.OP.I_L1_d*Inv.Filter.R1-Inv.OP.I_L1_q*Grid.wg*Inv.Filter.L1;          
Inv.OP.V_inv_q = Inv.OP.V_C_q+Inv.OP.I_L1_q*Inv.Filter.R1+Inv.OP.I_L1_d*Grid.wg*Inv.Filter.L1;  
Inv.OP.M_d = Inv.OP.V_inv_d/(0.5*Inv.OP.V_dc);
Inv.OP.M_q = Inv.OP.V_inv_q/(0.5*Inv.OP.V_dc);

% Inv.OP.Theta_pll = atan(Grid.wg*Inv.OP.I_L1_d*(Inv.Filter.L2+Grid.Lg)/(Grid.V_amp+Inv.OP.I_L1_d*(Inv.Filter.R2+Grid.Rg))); 

%% Transfer Function Definition
% unit matrix
I = eye(2);

% filter
Z_L1 = [(1i*w)*Inv.Filter.L1+Inv.Filter.R1, -Grid.wg*Inv.Filter.L1; Grid.wg*Inv.Filter.L1, (1i*w)*Inv.Filter.L1+Inv.Filter.R1];      
Y_C = [(1i*w)*Inv.Filter.C, -Grid.wg*Inv.Filter.C; Grid.wg*Inv.Filter.C, (1i*w)*Inv.Filter.C];                 
Z_L2 = [(1i*w)*Inv.Filter.L2+Inv.Filter.R2, -Grid.wg*Inv.Filter.L2; Grid.wg*Inv.Filter.L2, (1i*w)*Inv.Filter.L2+Inv.Filter.R2];      
Z_Rd = [Inv.Filter.Rd,0;0,Inv.Filter.Rd];

% ACC
G_ACCPR = [Ctrl.ACC.Kp+0.5*Ctrl.ACC.Kr/(1i*w)+0.5*Ctrl.ACC.Kr*(1i*w)/((1i*w)^2+4*Ctrl.ACC.wg^2), ...
           Ctrl.ACC.Kr*Ctrl.ACC.wg/((1i*w)^2+4*Ctrl.ACC.wg^2);...
          -Ctrl.ACC.Kr*Ctrl.ACC.wg/((1i*w)^2+4*Ctrl.ACC.wg^2), ...
           Ctrl.ACC.Kp+0.5*Ctrl.ACC.Kr/(1i*w)+0.5*Ctrl.ACC.Kr*(1i*w)/((1i*w)^2+4*Ctrl.ACC.wg^2)];      % PR controller in dq-frame
G_AD = [Ctrl.ACC.K_AD,0;0,Ctrl.ACC.K_AD];                                             % active damping

% delay and hold
% F_del = exp(-1i*(w)*Ctrl.Td_PWM);                           % delay function
F_del = (2-Ctrl.Td_PWM*(1i*w))/(2+Ctrl.Td_PWM*(1i*w));        % delay function
G_del = [F_del,0;0,F_del];                                    % delay matrix

% PLL 
F_PLL = Ctrl.PLL.Kp+Ctrl.PLL.Ki/(1i*w);             % PI controller of PLL in dq frame
H_PLL = F_PLL/((1i*w)+Inv.OP.V_C_d*F_PLL);          % small-signal model of PLL

% effect of PLL
G_PLL_I_ref = [0,-Inv.OP.I_L1_q*H_PLL;0,Inv.OP.I_L1_d*H_PLL];        % G_pll_i

%% Impedance Model of Inverter 
% impedance
Z_inv_w = (I-G_del*(G_ACCPR*G_PLL_I_ref+I-G_AD*Y_C))\(G_del*G_ACCPR+Z_L1);

%admittance
Y_inv_w = I/Z_inv_w;

%% Impedance Model of Inverter with L2, C
% impedance
Z_pcc_w = inv(inv(Z_inv_w)+inv(inv(Y_C)+Z_Rd))+Z_L2 ;
        
% admittance 
Y_pcc_w = I/Z_pcc_w;

%% Impedance Model of Grid
% impedance
Z_g_w = [(1i*w)*Grid.Lg+Grid.Rg, -Grid.wg*Grid.Lg; Grid.wg*Grid.Lg, (1i*w)*Grid.Lg+Grid.Rg]; 

% admittance
Y_g_w = I/Z_g_w;     

end