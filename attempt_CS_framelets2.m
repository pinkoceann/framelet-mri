%
% CS-framelet recon with general operator A
%
close all;clear all;clc;

addpath('./Framelet/'); %Jai Feng Cai's Framelet library
addpath('./BregmanCookbook/'); %Jerome Gilles' Bregman library (has some framelet stuff)
addpath('./nufft_files'); %Fessler+Greengard+Lustig's nufft

%use these all the time...
vec = inline('reshape(x,[numel(x) 1])','x');
unvec = inline('reshape(x,[m n])','x','m','n');

stream = RandStream('mt19937ar');

%img = double(rgb2gray(imread('bouchard_mri_clean.png')));
img = double(imread('phantom.gif'));
%load mri;
%img = double(D(:,:,1,19));
%img = double(rgb2gray(imread('cleanbrain.png')));
%img = double(imread('brainweb_t1.jpg'));

%resize to a nice square
n = 512;
img = imresize(img,[n n]);
m=n;

%number of sample for compressed sense
num_samples = round(m*n/2.5);


%% NUFFT setup
%using nufft, define the freq data locations
[k1pts k2pts] = meshgrid(1:m, 1:n);
k1pts = reshape(k1pts,numel(k1pts),1)*2*pi/m;
k2pts = reshape(k2pts,numel(k2pts),1)*2*pi/n;
omega = [k1pts k2pts];

%uniformly undersample
samp_coords = sort(randsample(stream, 1:max(size(omega)),num_samples));
omega = omega(samp_coords,:);


%the number of neighbors to use when interpolating the nufft
j1 = 6;
j2 = 6;
%the fft sizes? 2*n works nice. Its needed by the NUFFT library.
k1 = 2*m;
k2 = 2*n;

%make the nufft object
args = {omega, [m n], [j1 j2], [k1 k2]};
st = nufft_init(omega, [m n], [j1 j2], [k1 k2]);

%nufft is like fftw in that there is no normalization factor
scale_factor = sqrt(num_samples);

%% Create sample operator A
% A is a function handle, you'll need to make At as well.
% Note that input vectors and output vectors as needed by pcg. Note that the output of
% nufft_adj has m*n elements but nufft outputs num_samples x 1 column vecotr

%Create B and C, this is a well understood research problem and I'm not going to
%bother with making a better interpolator
L = 3;
T = .2;
mt = num_samples;
t = linspace(0.1,T,mt); %number of time points in the time discreization of continuous time
tl = linspace(0.1,T,L); %number of time points in to approximate at

%load the other guy's field map
load fmap_test.mat
fmap = imresize(fmap,size(img));
fmap = rot90(fmap,-1);

w = fmap/norm(fmap(:));

C = cell(1,L);
for l=1:L
    C{l} = vec(exp(1j*w*tl(l)));
end

B = cell(1,L);
for l=1:L
    B{l} = zeros(num_samples,1);
end
for l=1:L-1
    for i=1:num_samples
        if (tl(l) <= t(i)) && (t(i) <= tl(l+1))
            %B(i,(l-1)*N+1:l*N) = 1 - (t(i) - tl(l))/(tl(l+1) - tl(l));
            %B(i,l+1) = (t(i) - tl(l))/(tl(l+1) - tl(l));
            
            B{l}(i) = 1 - (t(i) - tl(l))/(tl(l+1) - tl(l));
            B{l+1}(i) = (t(i) - tl(l))/(tl(l+1) - tl(l));
        end
    end
end

%create sample operators
A = @(x) samplefun_nufft(st,B,C,x,m,n,0);
At = @(x) samplefun_nufft(st,B,C,x,m,n,1);

% 
%without nufft library
 fprintf('NO NUFFT!\n');
 R = zeros(m,n);
 sample_inds = randsample(stream, 1:m*n, num_samples);
 R(sample_inds) = 1.0;
% 
 B2 = zeros([size(R,1) L*size(R,2)]);
 C2 = zeros([size(R,1) L*size(R,2)])/L;
 for l=1:L
     Bee = zeros(size(R));
     Bee(sample_inds) = B{l};
     B2(:, (l-1)*n +1 : l*n) = Bee;
     
     C2(:, (l-1)*n +1 : l*n) = reshape(C{l},[m n]);

 end
     
 A = @(x) samplefun(R,B2,C2,x,0);
 At = @(x) samplefun(R,B2,C2,x,1);

%% Now that we have a system operator, sample the data in k space

%create sample data
f = A(vec(img));

%not sure why Tom did this normalization. It works really well though.
normFactor = 1/norm(f(:)/m);
f = f*normFactor;

%1 is for Haar, 2 is for framelet, 3 is for cubic framelet
%Haar sucks. 2 works best, 3 is slower and worse.
[D,Dt]=GenerateFrameletFilter(2);

%more levels is better? I don't know. Experimentally, more levels is slow
%and worse quality. Hmm.
n_level = 1;


%We minimize nu*|nabla u| + exci*|Du| st Au = f
nu = 1;
exci = 1;

%the splitting parameters. There's probably another optimization to figure
%how to pick the best ones...
mu = 1.5;
lambda = 1.4;
gamma = 25;

%the number of times I'm willing to apply A
maxiters = 231;

%watch a video as you do all this?
video = 1;

%% Run the reconstruction
tic
[u, errors, res_errors, errors_per_breg, res_error_per_breg, iters ] = bregman_cs_framelet(f, m, n, A, At, nu, exci, mu, lambda, gamma, maxiters, img, video);
toc

