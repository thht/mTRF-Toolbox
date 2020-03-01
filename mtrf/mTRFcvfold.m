function [strain,rtrain,stest,rtest] = mTRFcvfold(stim,resp,k,testfold,varargin)
%MTRFCVFOLD  Cross-validation fold partitioning.
%   [STRAIN,RTRAIN] = MTRFCVFOLD(STIM,RESP,K) partitions the stimulus and
%   response data into K equal folds for cross-validation. STIM and RESP
%   are vectors or matrices of continuous data and are returned in K-by-1
%   cell arrays. To utilize all available data, the number of samples in
%   each fold is rounded up and adjusted for in the last fold. If K is not
%   specified, it is set to 10 by default.
%
%   [STRAIN,RTRAIN,STEST,RTEST] = MTRFCVFOLD(STIM,RESP,K,TESTFOLD) returns
%   the fold specified by TESTFOLD as a separate test set and removes it
%   from the training set. STEST and RTEST are returned as vectors or
%   matrices. If TESTFOLD is not specified, it is chosen at random by
%   default.
%
%   [...] = MTRFCVFOLD(...,'PARAM1',VAL1,'PARAM2',VAL2,...) specifies
%   additional parameters and their values. Valid parameters are the
%   following:
%
%       Parameter   Value
%       'dim'       A scalar specifying the dimension to work along: pass
%                   in 1 to work along the columns (default), or 2 to work
%                   along the rows. Applies to both STIM and RESP.
%
%   See mTRFdemos for examples of use.
%
%   See also CVPARTITION, MTRFCROSSVAL.
%
%   mTRF-Toolbox https://github.com/mickcrosse/mTRF-Toolbox

%   References:
%      [1] Crosse MC, Di Liberto GM, Bednar A, Lalor EC (2016) The
%          multivariate temporal response function (mTRF) toolbox: a MATLAB
%          toolbox for relating neural signals to continuous stimuli. Front
%          Hum Neurosci 10:604.

%   Authors: Mick Crosse <mickcrosse@gmail.com>
%   Copyright 2014-2020 Lalor Lab, Trinity College Dublin.

% Parse input arguments
arg = parsevarargin(varargin);

% Set default values
if nargin < 3 || isempty(k)
    k = 10;
end
if nargin < 4 || isempty(testfold)
    testfold = randi(k,1);
end

% Orient data column-wise
if arg.dim == 2
    stim = stim';
    resp = resp';
end

% Get dimensions
sobs = size(stim,1);
robs = size(resp,1);

% Check equal number of observations
if ~isequal(sobs,robs)
    error(['STIM and RESP arguments must have the same number of '...
        'observations.'])
end

% Define fold size
fold = ceil(sobs/k);

% Generate training set
strain = cell(k,1);
rtrain = cell(k,1);
for i = 1:k
    idx = fold*(i-1)+1:min(fold*i,sobs);
    strain{i} = stim(idx,:);
    rtrain{i} = resp(idx,:);
end

if nargout > 2
    
    % Generate test set
    stest = strain{testfold};
    rtest = rtrain{testfold};
    
    % Remove test set from training set
    strain(testfold) = [];
    rtrain(testfold) = [];
    
end

function arg = parsevarargin(varargin)
%PARSEVARARGIN  Parse input arguments.
%   [PARAM1,PARAM2,...] = PARSEVARARGIN('PARAM1',VAL1,'PARAM2',VAL2,...)
%   parses the input arguments of the main function.

% Create parser object
p = inputParser;

% Dimension to work along
errorMsg = 'It must be a positive integer scalar within indexing range.';
validFcn = @(x) assert(x==1||x==2,errorMsg);
addParameter(p,'dim',1,validFcn);

% Parse input arguments
parse(p,varargin{1,1}{:});
arg = p.Results;