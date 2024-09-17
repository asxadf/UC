%% -------------------------------- RES -------------------------------- %%
% RES #01 Bus #49   [0, 0205]  Scaled Capacity: 200MW Flanders Elia
% RES #02 Bus #100  [0, 0789]  Scaled Capacity: 200MW Flanders DSO
% RES #03 Bus #59   [0, 0144]  Scaled Capacity: 200MW Wallonia Elia
% RES #04 Bus #92   [0, 0669]  Scaled Capacity: 200MW Wallonia DSO
% RES #05 Bus #70   [0, 2144]  Scaled Capacity: 200MW OFFSHORE
%
%
%% ---------------------------- RES_Farm_DAF --------------------------- %%
%  Column  #1         ... #5
%  Data    RES_01_DAF ... RES_05_DAF
%
%% ----------------------------- Load_Bus ----------------------------- %%
%  Column  #1                        ... #91
%  Data    Load_Bus_01 (24-1 Vector) ... Load_Bus_91 (24-1 Vector)
%
%% --------------------------- Gen_Capacity ---------------------------- %%
%  Column  #1           #2            #3          #4          #5        
%  Data    Number       Location_Bus  Max_Output  Min_Output  Minimal_On
%  Column  #6           #7            #8          #9          #10
%  Data    Minimal_Off  Ramp_Up       Ramp_Down   SU_Rampup   SD_Rampdown  
%  Column  #11          #12           
%  Data    R_H_max      R_C_max  
%
%% ----------------------------- Gen_Price ----------------------------- %%
%  Column  #1        #2        #3         #4         #5        #6
%  Data    Number    c0        c1         c2         SU_price  SD_price   
%
%% ------------------------------- Branch ------------------------------ %%
%  Column  #1    #2    #3         #4          
%  Data    Fbus  Tbus  Reactance  Capacity
%
%% --------------------------- Start function -------------------------- %%
function...
[Num_Gen,...
 Num_Branch,...
 Num_Bus,...
 Num_Bus_Load,...
 Num_Hour,...
 Num_RES,...
 Num_Seg,...
 Gen_Capacity,...
 Gen_Price,...
 Branch,...
 Load_System_DAF_All,...
 Load_System_DAF_Dis,...
 Load_Bus_DAF_All,...
 Load_Bus_DAF_Dis,...
 RES_SUM_DAF_All,...
 RES_SUM_DAF_Dis,...
 RES_Farm_DAF_All,...
 RES_Farm_DAF_Dis,...
 R_System_Req_All,...
 R_System_Req_Dis,...
 R_H_Req_All,...
 R_H_Req_Dis,...
 R_C_Req_All,...
 R_C_Req_Dis,...
 PTDF_Gen,...
 PTDF_Load,...
 PTDF_RES,...
 GS_Price,...
 LS_Price,...
 BS_Price,...
 Date_All_List,...
 Day,...
 Unit_Quick,...
 Unit_Thermal,...
 Gen_Price_PWL_Intercept,...
 Gen_Price_PWL_Slope,...
 Seg_Range,...
 BK_Point_Gen,...
 BK_Point_Cost] = Database_UC_Test(Date_Dispatch)
% Check
if exist('sdpvar', 'file') ~= 2
    error('YALMIP is not installed. Please install YALMIP to continue.');
end
%
if exist('gurobi', 'file') ~= 3
    error('Gurobi is not installed. Please install Gurobi to continue.');
end
%
%% ------------------------------ Loading ------------------------------ %%
disp('Loading...');
if ispc == 1
    Link = '\';
elseif ismac == 1
    Link = '/';
end
%
Ini_Path = which('Database_UC_Test.m');
Ini_Size = size('Database_UC_Test.m', 2);
Path_Data = Ini_Path(1:end - Ini_Size - 1);
%
Load_System_DAF = round(readmatrix(strcat(Path_Data, Link, 'Load_System_DAF', '.csv')));
RES_01_DAF       = round(readmatrix(strcat(Path_Data, Link, 'RES_01_DAF',     '.csv')));
RES_02_DAF       = round(readmatrix(strcat(Path_Data, Link, 'RES_02_DAF',     '.csv')));
RES_03_DAF       = round(readmatrix(strcat(Path_Data, Link, 'RES_03_DAF',     '.csv')));
RES_04_DAF       = round(readmatrix(strcat(Path_Data, Link, 'RES_04_DAF',     '.csv')));
RES_05_DAF       = round(readmatrix(strcat(Path_Data, Link, 'RES_05_DAF',     '.csv')));
Gen_Capacity     = readmatrix(strcat(Path_Data, Link, 'Gen_Capacity',         '.csv'));
Gen_Price        = readmatrix(strcat(Path_Data, Link, 'Gen_Price',            '.csv'));
Branch           = readmatrix(strcat(Path_Data, Link, 'Branch',               '.csv'));
Load_Bus_Index   = readmatrix(strcat(Path_Data, Link, 'Load_Bus_Index',       '.csv'));
Load_Bus_Weight  = readmatrix(strcat(Path_Data, Link, 'Load_Bus_Weight',      '.csv'));
%
%% ---------------------------- Basic Data ----------------------------- %%
Date_All_List =  (datetime('2020-01-01'):datetime('2020-12-31'))';
% Number of element
Num_Gen      = size(Gen_Capacity, 1);
Num_Branch   = size(Branch, 1);
Num_Bus      = max(max(Branch(:, 2:3)));
Num_Bus_Load = 91;
Num_Seg      = 3;
Num_BKPoint  = Num_Seg+1;
Num_RES      = 5;
Num_Hour     = 24;
Num_Day      = size(Load_System_DAF, 2);
%
% For SF
Ref_Bus = 69;
PTDF = Calculate_PTDF(Branch, Ref_Bus);
PTDF = round(PTDF, 4);
%
% Unit types
Unit_Gas  = [1;2;3;6;8;9;12;13;15;17;18];
Unit_Oil  = [31;32;33;38;41;42;46;49;50;54];
Unit_Coal = [4;5;7;10;11;14;16;19;20;21;22;23;24;25;26;27;28;29;30;34;35;...
             36;37;39;40;43;44;45;47;48;51;52;53];
Unit_Quick   = sort([Unit_Gas; Unit_Oil]);
Unit_Thermal = sort([Unit_Coal]);
%
% Find dispatch day
Day = find(Date_All_List == Date_Dispatch);
%
% Penalty price
LS_Price = 2000;
GS_Price = 2000;
BS_Price = 2000;
%
% RES bus
RES_01_Bus = 49;
RES_02_Bus = 100;
RES_03_Bus = 59;
RES_04_Bus = 92;
RES_05_Bus = 70;

RES_Bus = [RES_01_Bus; RES_02_Bus; RES_03_Bus; RES_04_Bus; RES_05_Bus];
%
% Scaler 
Scaler_Load   = 0.31;
Scaler_RES_01 = 1.00;
Scaler_RES_02 = 0.30;
Scaler_RES_03 = 1.50;
Scaler_RES_04 = 0.35;
Scaler_RES_05 = 0.10;
%
% Reserve level
R_for_Load_Gro = 0.3*ones(Num_Hour, 1);
R_H_Ratio = 0.3;
R_C_Ratio = 1 - R_H_Ratio;
Phi_R_H = R_H_Ratio*R_for_Load_Gro;
Phi_R_C = R_C_Ratio*R_for_Load_Gro;
%
% Confirm subhour
Subhour = 'hh:00';
if Subhour == 'hh:00'
    for i = 1:24
        Point(i, 1) = (i-1)*4+1;
    end
end
if Subhour == 'hh:15'
    for i = 1:24
        Point(i, 1) = (i-1)*4+2;
    end
end
if Subhour == 'hh:30'
    for i = 1:24
        Point(i, 1) = (i-1)*4+3;
    end
end
if Subhour == 'hh:45'
    for i = 1:24
        Point(i, 1) = (i-1)*4+4;
    end
end
% Tailoring transmission capacity
% Path for G4
Branch(7,   5) = 500;
Branch(9,   5) = 500;
% Path for G32
Branch(113, 5) = 30;
% Path for G39
Branch(133, 5) = 650;
Branch(134, 5) = 650;
% Path for G51
Branch(176, 5) = 100;
% Path for G52
Branch(177, 5) = 100;
% Path for G54
Branch(183, 5) = 50;
% Special branches
Branch(129, 5) = 600;
Branch(25,  5) = 500;
Branch(27,  5) = 500;
Branch(28,  5) = 500;
Branch(29,  5) = 500;
% Path between Zone1 and Zone2
Branch(45,  5) = 629;
Branch(54,  5) = 629;
Branch(108, 5) = 629;
Branch(116, 5) = 629;
Branch(120, 5) = 629;
Branch(185, 5) = 629;
% Path between Zone2 and Zone3
Branch(128, 5) = 754;
Branch(148, 5) = 754;
Branch(157, 5) = 754;
Branch(158, 5) = 754;
Branch(159, 5) = 754;
%
%% --------------------------- Load_Gro_SUM ---------------------------- %%
Load_System_DAF_All = Scaler_Load*Load_System_DAF(Point, :);
Load_System_DAF_Dis = Load_System_DAF_All(:, Day);
%
%% ----------------------------- Load_City ----------------------------- %%
for d = 1:Num_Day
    Load_Bus_DAF_All{1, d} = repmat(Load_System_DAF_All(:, d), 1, Num_Bus_Load);
    for c = 1:Num_Bus_Load
        Load_Bus_DAF_All{d}(:, c) = round(Load_Bus_Weight(c)*Load_Bus_DAF_All{d}(:, c), 2);
    end
end
Load_Bus_DAF_Dis = Load_Bus_DAF_All{Day};
%
%% -------------------------------- RES -------------------------------- %%
% For DAF
RES_01_All_DAF = Scaler_RES_01*RES_01_DAF(Point, :);
RES_02_All_DAF = Scaler_RES_02*RES_02_DAF(Point, :);
RES_03_All_DAF = Scaler_RES_03*RES_03_DAF(Point, :);
RES_04_All_DAF = Scaler_RES_04*RES_04_DAF(Point, :);
RES_05_All_DAF = Scaler_RES_05*RES_05_DAF(Point, :);
%
for d = 1:Num_Day
    % For DAF
    RES_Farm_DAF_All{d, 1} = [ RES_01_All_DAF(:, d)...
                               RES_02_All_DAF(:, d)...
                               RES_03_All_DAF(:, d)...
                               RES_04_All_DAF(:, d)...
                               RES_05_All_DAF(:, d) ];
    RES_SUM_DAF_All(:, d) = sum(RES_Farm_DAF_All{d}, 2);

end
RES_SUM_DAF_Dis  = RES_SUM_DAF_All(:, Day);
RES_Farm_DAF_Dis = RES_Farm_DAF_All{Day};
%
%% --------------------------- Reserve Level --------------------------- %%
for d = 1:Num_Day
    R_H_Req_All(:, d) = Phi_R_H.*Load_System_DAF_All(:, d);
    R_C_Req_All(:, d) = Phi_R_C.*Load_System_DAF_All(:, d);
end
R_H_Req_Dis = R_H_Req_All(:, Day);
R_C_Req_Dis = R_C_Req_All(:, Day);
%
R_System_Req_All = R_H_Req_All + R_C_Req_All;
R_System_Req_Dis = R_H_Req_Dis + R_C_Req_Dis;
%
%% ------------------------------- PTDF -------------------------------- %%
for i = 1:Num_Gen
    PTDF_Gen(:,i) = PTDF(:, Gen_Capacity(i, 2));
end
for i = 1:Num_Bus_Load
    PTDF_Load(:,i) = PTDF(:, Load_Bus_Index(i, 1));
end
for i = 1:Num_RES
    PTDF_RES(:,i) = PTDF(:, RES_Bus(i, 1));
end
disp('Modeling...');
%
%% ------------------------------- PWL -------------------------------- %%
Seg_Range = (Gen_Capacity(:, 3) - Gen_Capacity(:, 4))/Num_Seg;
BK_Point_Gen = zeros(Num_Gen, Num_BKPoint);
BK_Point_Cost = zeros(Num_Gen, Num_BKPoint);
Gen_Price_PWL_Intercept = zeros(Num_Gen, Num_Seg);
Gen_Price_PWL_Slope = zeros(Num_Gen, Num_Seg);
for i = 1:Num_Gen    
    for z = 1:Num_BKPoint
        BK_Point_Gen(i, z) = Gen_Capacity(i, 4) + (z-1)*Seg_Range(i, 1);
        BK_Point_Cost(i, z) = Gen_Price(i, 2)...
                            + Gen_Price(i, 3).*BK_Point_Gen(i, z)...
                            + Gen_Price(i, 4).*BK_Point_Gen(i, z).^2;
    end
end
%
for i = 1:Num_Gen                   
    for k = 1:Num_Seg
        Gen_Price_PWL_Slope(i, k) = (BK_Point_Cost(i, k+1) - BK_Point_Cost(i, k))/Seg_Range(i);
        Gen_Price_PWL_Intercept(i, k) = BK_Point_Cost(i, k) - Gen_Price_PWL_Slope(i, k)*BK_Point_Gen(i, k) ;
    end
end