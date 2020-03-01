function [stats,t] = mTRFmulticrossval(stim,resp,resp1,resp2,fs,dir,tmin,tmax,lambda,varargin)
%MTRFMULTICROSSVAL  Cross-validation for multisensory additive models.
%   STATS = MTRFMULTICROSSVAL(STIM,RESP,RESP1,RESP2,FS,DIR,TMIN,TMAX,LAMBDA)
%   cross validates a forward encoding model (stimulus to neural response)
%   or a backward decoding model (neural response to stimulus) over
%   multiple trials of data for building a model of multisensory
%   processing. Models are trained on the sum of the unisensory responses
%   RESP1 and RESP2 (i.e., the additive model of multisensory processing),
%   and validated on the actual multisensory responses RESP as per Crosse
%   et al. (2015). Pass in 1 for DIR to validate a forward model, or -1 to
%   validate a backward model. STIM, RESP, RESP1 and RESP2 are cell arrays
%   containing corresponding trials of continuous data. FS is a scalar
%   specifying the sample rate in Hertz, and TMIN  and TMAX are scalars
%   specifying the minimum and maximum time lags in milliseconds. For
%   backward models, MTRFMULTICROSSVAL automatically reverses the time
%   lags. LAMBDA is a scalar or vector of regularization values to be
%   validated and controls overfitting.
%
%   STATS = MTRFMULTICROSSVAL(...) returns the cross-validation statistics
%   in a structure with the following fields:
%       'acc'       -- prediction accuracy based on Pearson's correlation
%                      coefficient (ntrial-by-nlambda-by-yvar)
%       'err'       -- prediction error based on the mean squared error
%                      (ntrial-by-nlambda-by-yvar)
%
%   MTRFMULTICROSSVAL performs a leave-one-out cross-validation over all
%   trials. To achieve a k-fold cross-validation, arrange STIM, RESP, RESP1
%   and RESP2 in k-by-1 cell arrays. The number of folds can also be
%   increased by an integer factor using the 'split' parameter (see below).
%
%   If STIM, RESP, RESP1 or RESP2 contain matrices, it is assumed that the
%   rows correspond to observations and the columns to variables, unless
%   otherwise stated via the 'dim' parameter (see below). If they contain
%   vectors, it is assumed that the first non-singleton dimension
%   corresponds to observations. Each trial of STIM, RESP, RESP1 or RESP2
%   must have the same number of observations.
%
%   [STATS,T] = MTRFMULTICROSSVAL(...) returns a vector containing the time
%   lags used in milliseconds. These data are useful for interpreting the
%   results of single-lag models.
%
%   [...] = MTRFMULTICROSSVAL(...,'PARAM1',VAL1,'PARAM2',VAL2,...)
%   specifies additional parameters and their values. Valid parameters are
%   the following:
%
%       Parameter   Value
%       'dim'       A scalar specifying the dimension to work along: pass
%                   in 1 to work along the columns (default), or 2 to work
%                   along the rows. Applies to both STIM and RESP.
%       'method'    A string specifying the regularization method to use:
%                       'ridge'     ridge regression (default): suitable
%                                   for multivariate input features
%                       'Tikhonov'  Tikhonov regularization: dampens fast
%                                   oscillatory components of the solution
%                                   but may cause cross-channel leakage for
%                                   multivariate input features
%                       'ols'       ordinary least squares: equivalent to
%                                   setting LAMBDA=0 (no regularization)
%       'type'      A string specifying type of model to fit:
%                       'multi'     use all lags simultaneously to fit a
%                                   multi-lag model (default)
%                       'single'    use each lag individually to fit
%                                   separate single-lag models
%       'acc'       A string specifying the accuracy metric to use:
%                       'Pearson'   Pearson's linear correlation
%                                   coefficient (default): suitable for
%                                   data with a linear relationship
%                       'Spearman'  Spearman's rank correlation
%                                   coefficient: suitable for data with
%                                   non-linear relationship
%       'err'       A string specifying the error metric to use:
%                       'msc'       Mean square error (default): take the
%                                   square root to convert it to the
%                                   original units of the data (i.e., RMSE)
%                       'mae'       Mean absolute error: more robust to
%                                   outliers than MSE
%       'split'     A scalar specifying the number of segments in which to
%                   split each trial of data when computing the covariance
%                   matrices. This is useful for reducing memory usage on
%                   large datasets. By default, the entire trial is used.
%       'zeropad'   A numeric or logical specifying whether to zero-pad the
%                   outer rows of the design matrix or delete them: pass in
%                   1 to zero-pad them (default), or 0 to delete them.
%       'fast'      A numeric or logical specifying whether to use the fast
%                   cross-validation method (requires more memory) or the
%                   slower method (requires less memory): pass in 1 to use
%                   the fast method (default) or 0 to use the slower
%                   method. Note, both methods are numerically equivalent.
%
%   Notes:
%   Each iteration of MTRFMULTICROSSVAL partitions the N trials of data
%   into two subsets, fitting a model to N-1 trials (training set) and
%   testing on the left-out trial (validation set). Performance on the
%   validation set can be used to optimize hyperparameters (e.g., LAMBDA).
%   Once completed, it is recommended to test the model performance on
%   separate held-out data using the mTRFpredict function.
%
%   Discontinuous trials of data should not be concatenated prior to cross-
%   validation as this will introduce artifacts in places where time lags
%   cross over trial boundaries. Each trial should be input as an
%   individual cell of continuous data and MTRFMULTICROSSVAL will zero-pad
%   the trial boundaries appropriately.
%
%   See mTRFdemos for examples of use.
%
%   See also MTRFTRAIN, MTRFPREDICT, MTRFTRANSFORM, MTRFAADCROSSVAL.
%
%   mTRF-Toolbox https://github.com/mickcrosse/mTRF-Toolbox

%   References:
%      [1] Crosse MC, Di Liberto GM, Bednar A, Lalor EC (2016) The
%          multivariate temporal response function (mTRF) toolbox: a MATLAB
%          toolbox for relating neural signals to continuous stimuli. Front
%          Hum Neurosci 10:604.
%      [2] Crosse MC, Butler JS, Lalor EC (2015) Congruent Visual Speech
%          Enhances Cortical Entrainment to Continuous Auditory Speech in
%          Noise-Free Conditions. J Neurosci 35(42):14195-14204.

%   Authors: Mick Crosse <mickcrosse@gmail.com>
%            Giovanni Di Liberto <diliberg@tcd.ie>
%            Edmund Lalor <edmundlalor@gmail.com>
%            Nate Zuk <zukn@tcd.ie>
%   Copyright 2014-2020 Lalor Lab, Trinity College Dublin.

% Parse input arguments
arg = parsevarargin(varargin);

% Validate input parameters
if ~isnumeric(fs) || ~isscalar(fs) || fs <= 0
    error('FS argument must be a positive numeric scalar.')
elseif ~isnumeric([tmin,tmax]) || ~isscalar(tmin) || ~isscalar(tmax)
    error('TMIN and TMAX arguments must be numeric scalars.')
elseif tmin > tmax
    error('The value of TMIN must be less than that of TMAX.')
elseif ~isnumeric(lambda) || any(lambda < 0)
    error('LAMBDA argument must be positive numeric values.')
end

% Define X and Y variables
if dir == 1
    x = stim; y = resp;
elseif dir == -1
    x = resp; y = stim;
    [tmin,tmax] = deal(tmax,tmin);
else
    error('DIR argument must have a value of 1 or -1.')
end

% Format data in cell arrays
[x,xobs,xvar] = formatcells(x,arg.dim);
[y,yobs,yvar] = formatcells(y,arg.dim);
[z1,zobs1,~] = formatcells(resp1,arg.dim);
[z2,zobs2,~] = formatcells(resp2,arg.dim);

% Check equal number of observations
if ~isequal(xobs,yobs,zobs1,zobs2)
    error(['STIM and RESP arguments must have the same number of '...
        'observations.'])
end

% Convert time lags to samples
tmin = floor(tmin/1e3*fs*dir);
tmax = ceil(tmax/1e3*fs*dir);
lags = tmin:tmax;

% Compute sampling interval
delta = 1/fs;

% Get dimensions
xvar = unique(xvar);
yvar = unique(yvar);
switch arg.type
    case 'multi'
        mvar = xvar*numel(lags)+1;
        nlag = 1;
    case 'single'
        mvar = xvar+1;
        nlag = numel(lags);
end
ntrial = numel(x);
nbatch = ntrial*arg.split;
nlambda = numel(lambda);

% Compute unisensory covariance matrices
if arg.fast
    sumcov = 0;
else
    sumcov = 1;
end
if dir == 1
    [CXX,CXY1,CXY2] = mlscovmat(x,z1,z2,lags,arg.type,arg.split,...
        arg.zeropad,sumcov);
elseif dir == -1
    [CXX1,CXY1] = olscovmat(z1,y,lags,arg.type,arg.split,arg.zeropad,...
        sumcov);
    [CXX2,CXY2] = olscovmat(z2,y,lags,arg.type,arg.split,arg.zeropad,...
        sumcov);
end

% Compute covariances of additive model
if dir == 1
    if arg.fast
        for i = 1:nbatch
            CXX{i} = CXX{i} + CXX{i};
            CXY{i} = CXY1{i} + CXY2{i};
        end
    else
        CXX = CXX + CXX;
        CXY = CXY1 + CXY2;
    end
elseif dir == -1
    if arg.fast
        for i = 1:nbatch
            CXX{i} = CXX1{i} + CXX2{i};
            CXY{i} = CXY1{i} + CXY2{i};
        end
    else
        CXX = CXX1 + CXX2;
        CXY = CXY1 + CXY2;
    end
end

% Set up sparse regularization matrix
M = sparse(eye(mvar));
switch arg.method
    case 'ridge'
        M(1,1) = 0;
    case 'Tikhonov'
        M = M - 0.5*(diag(ones(mvar-1,1),1)+diag(ones(mvar-1,1),-1));
        M([mvar+2,end]) = 0.5;
        M([1,2,mvar+1]) = 0;
    case 'ols'
        lambda(:) = 0;
end
M = M/delta;

% Initialize performance variables
acc = zeros(ntrial*arg.split,nlambda,yvar,nlag);
err = zeros(ntrial*arg.split,nlambda,yvar,nlag);

% Leave-one-out cross-validation
n = 0;
for i = 1:ntrial
    
    % Max segment size
    nseg = ceil(xobs(i)/arg.split);
    
    for j = 1:arg.split
        
        n = n+1;
        
        % Segment indices
        iseg = nseg*(j-1)+1:min(nseg*j,xobs(i));
        
        % Multisensory validation set
        [xlag,idx] = lagGen(x{i}(iseg,:),lags,arg.zeropad);
        xlag = [ones(numel(idx),1),xlag]; %#ok<*AGROW>
        
        if arg.fast % fast method
            
            % Unisensory training set
            idx = 1:nbatch; idx(n) = [];
            Cxx = 0; Cxy = 0;
            for k = idx
                Cxx = Cxx + CXX{k};
                Cxy = Cxy + CXY{k};
            end
            
        else % memory-efficient method
            
            % Unisensory left-out set
            [z1lag,idx] = lagGen(x{i}(iseg,:),lags,arg.zeropad);
            z1lag = [ones(numel(idx),1),z1lag];
            [z2lag,idx] = lagGen(x{i}(iseg,:),lags,arg.zeropad);
            z2lag = [ones(numel(idx),1),z2lag];
            
            % Unisensory training set
            Cxx = CXX - z1lag'*z1lag - z2lag'*z2lag;
            Cxy = CXY - z1lag'*y{i}(iseg(idx),:) - z2lag'*y{i}(iseg(idx),:);
            
        end
        
        % Remove zero-padded indices
        if ~arg.zeropad
            iseg = iseg(1+max(0,lags(end)):end+min(0,lags(1)));
        end
        
        for k = 1:nlambda
            
            switch arg.type
                
                case 'multi'
                    
                    % Fit linear additive model
                    w = (Cxx + lambda(k)*M)\Cxy;
                    
                    % Account for superposition
                    w = w*2;
                    
                    % Predict multisensory output
                    pred = xlag*w;
                    
                    % Evaluate performance
                    [acc(n,k,:),err(n,k,:)] = mTRFevaluate(y{i}(iseg,:),...
                        pred,'acc',arg.acc,'err',arg.err);
                    
                case 'single'
                    
                    for l = 1:nlag
                        
                        % Fit linear additive model
                        w = (Cxx(:,:,l) + lambda(k)*M)\Cxy(:,:,l);
                        
                        % Account for superposition
                        w = w*2;
                        
                        % Predict multisensory output
                        ilag = [1,xvar*(l-1)+2:xvar*l+1];
                        pred = xlag(:,ilag)*w;
                        
                        % Evaluate performance
                        [acc(n,k,:,l),err(n,k,:,l)] = ...
                            mTRFevaluate(y{i}(iseg,:),pred,...
                            'acc',arg.acc,'err',arg.err);
                        
                    end
                    
            end
            
        end
        
    end
    
end

% Format output arguments
stats = struct('acc',acc,'err',err);
if nargout > 1
    t = lags/fs*1e3;
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

% Regularization method
regOptions = {'ridge','Tikhonov','ols'};
validFcn = @(x) any(validatestring(x,regOptions));
addParameter(p,'method','ridge',validFcn);

% Model type
lagOptions = {'multi','single'};
validFcn = @(x) any(validatestring(x,lagOptions));
addParameter(p,'type','multi',validFcn);

% Accuracy metric
accOptions = {'Pearson','Spearman'};
validFcn = @(x) any(validatestring(x,accOptions));
addParameter(p,'acc','Pearson',validFcn);

% Error metric
errOptions = {'mse','mae'};
validFcn = @(x) any(validatestring(x,errOptions));
addParameter(p,'err','mse',validFcn);

% Split data
errorMsg = 'It must be a positive integer scalar.';
validFcn = @(x) assert(isnumeric(x)&&isscalar(x),errorMsg);
addParameter(p,'split',1,validFcn);

% Boolean arguments
errorMsg = 'It must be a numeric scalar (0,1) or logical.';
validFcn = @(x) assert(x==0||x==1||islogical(x),errorMsg);
addParameter(p,'zeropad',true,validFcn); % zero-pad design matrix
addParameter(p,'fast',true,validFcn); % fast CV method
addParameter(p,'gpu',false,validFcn); % run on GPU

% Parse input arguments
parse(p,varargin{1,1}{:});
arg = p.Results;

% Redefine partially-matched strings
arg.method = validatestring(arg.method,regOptions);
arg.type = validatestring(arg.type,lagOptions);
arg.acc = validatestring(arg.acc,accOptions);
arg.err = validatestring(arg.err,errOptions);