function [x_data_fit,y_data_fit] = sum_fitted_data(fit1,fit2,mu1,sigma1,mu2,sigma2)
x_data1 = fit1.XData;
y_data1 = fit1.YData;

x_data2 = fit2.XData;
y_data2 = fit2.YData;

integral1 = trapz(x_data1,y_data1);
integral2 = trapz(x_data2,y_data2);

min_value = min([x_data1(2)-x_data1(1) x_data2(2)-x_data2(1)]);
min_value = min_value/5;

x_data_fit = x_data1(1):min_value:x_data2(end);
y_data_fit1 = integral1*normpdf(x_data_fit,mu1,sigma1);
y_data_fit2 = integral2*normpdf(x_data_fit,mu2,sigma2);
y_data_fit = y_data_fit1 + y_data_fit2;
end