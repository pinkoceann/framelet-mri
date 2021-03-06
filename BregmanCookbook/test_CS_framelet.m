%
% Test framelet cs reconstrunction...
%
close all;clear all;clc;

addpath('../Framelet/');


f = rgb2gray(imread('../blurred.png'));

A = fspecial('disk',3);

%f = conv2(f,A,'same');

mu = 1000;
lambda = 0.5;
Niter = 5;
frame = 0;
Nlevel = 3;

u = Framelet_NB_Deconvolution(f,A,mu,lambda,Niter,frame,Nlevel,0);

imagesc(f)
colormap bone

figure()
imagesc(u);
colormap bone