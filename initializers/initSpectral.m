%                           initSpectral.m
%
% Intializer proposed in Algorithm 1 of the Wirtinger Flow paper . This
% initializer forms a matrix from the data and computes the largest
% eigenvector that is shown to be positively correlated with the unknown
% true signal. This script presents both the vanilla spectral method and
% the truncated spectral method. A recently proposed 'optimal' spectral
% initializer method was proposed and is presented in a different file.
%% I/O
%  Inputs:
%     A:  m x n matrix (or optionally a function handle to a method) that
%         returns A*x.
%     At: The adjoint (transpose) of 'A'. If 'A' is a function handle, 'At'
%         must be provided.
%     b0: m x 1 real, non-negative vector consists of all the measurements.
%     n:  The size of the unknown signal. It must be provided if A is a 
%         function handle.
%     isTruncated (boolean): If true, use the 'truncated' initializer that
%                            uses a sub-sample of the measurement.
%     isScaled (boolean):    If true, use a least-squares method to
%                            determine  the optimal scale of the
%                            initializer.
%
%     Note: When a function handle is used, the value of 'n' (the length of
%     the unknown signal) and 'At' (a function handle for the adjoint of
%     'A') must be supplied.  When 'A' is numeric, the values of 'At' and
%     'n' are ignored and inferred from the arguments.
%
%  Outputs:
%     x0:  A n x 1 vector. It is the guess generated by the spectral method
%          for  the unknown signal.

%  See the script 'testInitSpectral.m' for an example of proper usage of
%  this function.
%
%% Notations
%  Our notations follow the TWF paper.
%  ai is the conjugate transpose of the ith row of A.
%  yi is the ith element of y, which is the element-wise square of the
%  measurements b0.
%
%% Algorithm Description
%  The method has two steps
%  (1) If isTruncated==true, Discard those observations yi that are
%      several times greater than the mean during spectral initialization.
%  (2) Calculate the leading eigenvector of a matrix Y,
%      where Y = 1/m sum(yi * ai * ai') for i = 1 to m.
%  The method return this leading eigenvector, which is calcualted using
%  Matlab's eigs() routine. Note: The truncation, when used, makes the
%  method more robust to outliers and performs better in practice.
%
%  For a detailed explanation, see Algorithm 1 in the TWF paper referenced
%  below.
%
%  Note:
%  The papers below recommend using the power method to compute the leading
%  eigenvector.  Our implemention uses Matlab's built-in function eigs() 
%  to get the leading eigenvector because of greater efficiency.

%% References
%  For spectral method
%  Paper Title:   Phase Retrieval via Wirtinger Flow: Theory and Algorithms
%  Place:         Algorithm 1
%  Authors:       Emmanuel Candes, Xiaodong Li, Mahdi Soltanolkotabi
%  Arxiv Address: https://arxiv.org/abs/1407.1065
%
%  For truncated spectral method
%  Paper Title:   Solving Random Quadratic Systems of Equations Is Nearly as
%                 Easy as Solving Linear Systems
%  Place:         Algorithm 1
%  Authors:       Yuxin Chen, Emmanuel J. Candes
%  Arxiv Address: https://arxiv.org/abs/1505.05114
%
%
% PhasePack by Rohan Chandra, Ziyuan Zhong, Justin Hontz, Val McCulloch,
% Christoph Studer, & Tom Goldstein 
% Copyright (c) University of Maryland, 2017

%% -----------------------------START----------------------------------


function [x0] = initSpectral(A,At,b0,n,isTruncated,isScaled,verbose)

% If A is a matrix, infer n and At from A. Transform matrix into function form.
if isnumeric(A)
    n = size(A, 2);
    At = @(x) A' * x;
    A = @(x) A * x;
end

m = numel(b0);                % number of measurements

if ~exist('verbose','var') || verbose
fprintf(['Estimating signal of length %d using a spectral initializer ',...
        'with %d measurements...\n'],n,m);
end

% Truncated Wirtinger flow initialization
alphay = 3;                   % (4 also works fine)
y = b0.^2;                    % To be consistent with the notation in the TWF paper Algorithm 1.
lambda0 = sqrt(1/m * sum(y)); % Defined in the TWF paper Algorithm 1
idx = ones(size(b0));         % Indices of observations yi

% Truncate indices if isTruncated is true
% It discards those observations yi that are several times greater than
% the mean during spectral initialization.
if isTruncated
    idx = abs(y) <= alphay^2 * lambda0^2;
end

% Build the function handle associated to the matrix Y
% in the TWF paper Algorithm 1
Yfunc = @(x) 1/m*At((idx.*b0.^2).*A(x));

% Our implemention uses Matlab's built-in function eigs() to get the leading
% eigenvector because of greater efficiency.
% Create opts struct for eigs
opts = struct;
opts.isreal = false;

% Get the eigenvector that corresponds to the largest eigenvalue of the
% associated matrix of Yfunc.
[x0,~] = eigs(Yfunc, n, 1, 'lr', opts);

% This part does not appear in the paper. We add it for better
% performance. Rescale the solution to have approximately the correct
% magnitude
if isScaled
    % Pick measurements according to the indices selected
    b = b0.*idx;
    Ax = abs(A(x0)).*idx;
    
    % solve min_s || s|Ax| - b ||
    u = Ax.*b;
    l = Ax.*Ax;
    s = norm(u(:))/norm(l(:));
    x0 = x0*s;                   % Rescale the estimation of x
end

if ~exist('verbose','var') || verbose
fprintf('Initialization finished.\n');
end

end
