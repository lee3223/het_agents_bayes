% Computes and analyzes steady state with no aggregate shocks
% 2019-02-04

clear all;
close all;

% profile on
oldFolder = cd('./auxiliary_functions/dynare');


%% Define parameters

% ECONOMIC PARAMETERS

% Preferences
bbeta = .99; % Discount factor
ppsi = 3; % Coefficient on labor disutility
nnu = 1; % Inverse Frisch elasticity, MUST be 1 at the moment!

% Borrowing limit
bbBar = -1;

% Production
eepsilon = 5;

% Taxes
ttau = 0.3;
vvarthetaB = -0.233;
vvarthetaT = 0.06;

% Idiosyncratic productivity
vzGrid = [0.5;1;1.5];
mzTransition = [0.8 0.2 0;
                0.1 0.8 0.1;
                0   0.2 0.8]; % (i,j) element: P(z'=z_j | z=z_i)
% vzGrid = [0.5;1.5];
% mzTransition = [0.8 0.2;
%                 0.2 0.8]; % (i,j) element: P(z'=z_j | z=z_i)

% Aggregate productivity
A_SS = 1; % Steady state aggr productivity level

% Equity shares
% vShareGrid = [0; 1; 2]; % Profit shares for each household type
% vShareFraction = [1/3; 1/3; 1/3]; % Fractions of each household type
% vShareGrid = [0; 2];
% vShareFraction = [1/2; 1/2];
vShareGrid = 1;
vShareFraction = 1;


% APPROXIMATION PARAMETERS

% Whether to print out results from steady state computation
displayOpt = 'iter-detailed';       % 'iter-detailed' or 'off'

% Order of approximation
nAssets = 25; % number of polynomials in polynomial approximation

% Finer grid for analyzing policy functions
nAssetsFine = 100;

% Approximation of distribution
nMeasure = 3;
nAssetsQuadrature = 8;

% Steady state
tolerance_SS_root = 0.001; % Numerical tolerance for root finding
tolerance_SS_invhist = 1e-12; % Numerical tolerance for invariant distribution of histogram approach
maxIterations = 2e4;
tolerance = 1e-5;
dampening = .5;%.95;
numNewton = 10; % Number of Newton steps per iteration in parametric ss calculation


%% Compute remaining parameters

% Set additional parameters
setParameters;

% Grids
computeGrids;

% Polynomials over grids (use polynomials to approximate conditional expectation)
computePolynomials;


%% Compute Steady State

% Solve for steady state
coreSteadyState;
% profile viewer;
% profsave(profile('info'),['profile_results_' datestr(now,'yyyymmdd')]);


%% Compare histogram and parametric steady states

indShare = 1; % Plot for this index of profit share

% Grid for computing PDF
bGridMoments_fine = zeros(nz,nAssetsFine,nMeasure);
for iz = 1 : nz
    bGridMoments_fine(iz,:,1) = vAssetsGridFine - mMoments(iz,1,indShare);
	for iMoment = 2 : nMeasure
		bGridMoments_fine(iz,:,iMoment) = (vAssetsGridFine - mMoments(iz,1,indShare)) .^ ...
			iMoment - mMoments(iz,iMoment,indShare);
	end	
end

% Log asset density away from constraint
logdens_fine = zeros(nz,nAssetsFine);
for iMoment=1:nMeasure
    logdens_fine = logdens_fine + bGridMoments_fine(:,:,iMoment).*mParameters(:,iMoment+1,indShare);
end

% Conditional expectation function, parametric SS
chidT_SS = d_SS*vShareGrid(indShare)+T_SS;
mConditionalExpectation = exp(mCoefficients(:,:,indShare) * computeChebyshev(nAssets,scaleDown(vAssetsGridFine,assetsMin,assetsMax))');
% Compute savings policy
mAssetsPrimeStar = ((1-ttau)*w_SS*mzGridFine).^(1+1/nnu).*(mConditionalExpectation/ppsi).^(1/nnu) ...
                    +(1+r_SS)*mAssetsGridFine+chidT_SS-1./mConditionalExpectation;
mAssetsPrime = max(mAssetsPrimeStar,bbBar);

% Compute labor and consumption
% ASSUMES nnu=1!
mConstr = (mAssetsPrime==bbBar);
mLabor = (1-ttau)*w_SS*mzGridFine.*mConditionalExpectation/ppsi; % Labor supply if savings not constrained
aux = -bbBar + (1+r_SS)*mAssetsPrime(mConstr) + chidT_SS;
mLabor(mConstr) = (-aux + sqrt(aux.^2 + 4*((1-ttau)*w_SS*mzGridFine(mConstr)).^2/ppsi)) ...
                       ./ (2*(1-ttau)*w_SS*mzGridFine(mConstr)); % If savings constrained
mConsumption = (1-ttau)*w_SS*mzGridFine./(ppsi*mLabor); % Consumption

% Plot asset histograms/densities
figure('Units', 'normalize', 'Position', [0.1 0.2 0.8 0.6]);
plot_fct(vAssetsGridFine,mHistogram(:,:,indShare)./sum(mHistogram(:,:,indShare),2),1,'Asset distribution: histogram');
plot_fct(vAssetsGridFine,mParameters(:,1,indShare).*exp(logdens_fine),2,'Asset distribution: parametric');

% Plot savings policy
figure('Units', 'normalize', 'Position', [0.1 0.2 0.8 0.6]);
plot_fct(vAssetsGridFine,mAssetsPrime_hist(:,:,indShare),1,'Savings policy: histogram');
plot_fct(vAssetsGridFine,mAssetsPrime,2,'Savings policy: parametric');

% Plot consumption policy
figure('Units', 'normalize', 'Position', [0.1 0.2 0.8 0.6]);
plot_fct(vAssetsGridFine,mConsumption_hist(:,:,indShare),1,'Consumption policy: histogram');
plot_fct(vAssetsGridFine,mConsumption,2,'Consumption policy: parametric');

% Plot labor supply policy
figure('Units', 'normalize', 'Position', [0.1 0.2 0.8 0.6]);
plot_fct(vAssetsGridFine,mLabor_hist(:,:,indShare),1,'Labor supply policy: histogram');
plot_fct(vAssetsGridFine,mLabor,2,'Labor supply policy: parametric');


cd(oldFolder);


function plot_fct(x,y,no,titl)
    % Side-by-side plot with grid
    subplot(1,2,no);
    plot(x,y,'LineWidth',2);
    title(titl);
    grid on;
end