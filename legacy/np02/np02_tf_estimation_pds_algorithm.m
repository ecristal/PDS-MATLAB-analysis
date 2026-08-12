%%% algoritmo para identificar la funcion de transferencia 
% Esteban Javier Cristaldo Morales
%clear all

%dante_undershoot_mitigator_filter
%daphne_lead_lag_compensator
%linearity_big_signals
load("templates_np02_large_pulses.mat")
close all
%dante
number = 16
waveform = spe_template_struct(number).data;
starting_point = 250;
output_data = waveform/max(waveform);
output_data = output_data - mean(output_data(1:50));
plot(output_data)

% DMEM
%starting_point = 532;
%output_data = pasive_compensated_tuned_waveform;
% output_data = output_data - output_data(starting_point);
% output_data(1:starting_point) = zeros(1,starting_point);
Tm = 16e-9;
f = 1/Tm;
% [numf,denf] = butter(4,7.5e6/(f/2),'low');
% output_data = filter(numf,denf,output_datai);
input_data = zeros(1,length(output_data));
input_data(starting_point+5) = 1;

order = 4
order_max = order;
circ_start = -10;
circ_stop = 20;
fit_percent = zeros(order_max,length(circ_start:1:circ_stop));

for ord=order:order_max
    ord
    for i=circ_start:circ_stop
        data_to_est = iddata(output_data',circshift(input_data,i)', Tm);
        tf_model = tfest(data_to_est,ord+1,ord);
        fit_percent(ord,i-circ_start+1) = tf_model.Report.Fit.FitPercent;
    end
end


% max_i = -40

h = figure(1)
hp = plot(circ_start:circ_stop,fit_percent')
grid on 
[max_value,max_i] = max(fit_percent(order,:));

set(h,'Position',[100,100,800,600])
title('Transfer function estimation - FBK', 'Interpreter', 'latex')
xlabel('Time shift[samples]', 'Interpreter', 'latex')
ylabel('Goodness of fit$[\%]$', 'Interpreter', 'latex')
legend('Order 1','Order 2','Order 3','Order 4','Order 5', 'Order 6','interpreter','latex')
set(findall(gcf, 'Type', 'text'), 'Interpreter', 'latex');
set(findall(gcf, 'Type', 'text'), 'FontSize',16);
set(hp,'LineWidth',1.5)

h = figure(2)
hp = plot(circ_start:circ_stop,fit_percent');
hold on 
xline(max_i+circ_start-1,'r-.')
scatter(max_i+circ_start-1,max_value,'r*')
grid on 

%set(gca,'YLim',[99.5,100])
set(h,'Position',[100,100,800,600])
title('Transfer function estimation - FBK', 'Interpreter', 'latex')
xlabel('Time shift[samples]', 'Interpreter', 'latex')
ylabel('Goodness of fit$[\%]$', 'Interpreter', 'latex')
legend('Order 1','Order 2','Order 3','Order 4','Order 5', 'Order 6','interpreter','latex')
set(findall(gcf, 'Type', 'text'), 'Interpreter', 'latex');
set(findall(gcf, 'Type', 'text'), 'FontSize',16);
set(hp,'LineWidth',1.5)

data_to_est = iddata(output_data',circshift(input_data,max_i+circ_start-1)', Tm);
tf_model = tfest(data_to_est,order+1,order);

tiempo = 0:Tm:(length(input_data)-1)*Tm;

tf_model_d = c2d(tf_model,Tm,'zoh');

[numh,denh] = butter(1,80e3/(f/2),'high');
    
h = figure(3)
plot(tiempo*1e6,output_data,'LineWidth',1.5)
hold on 
grid on

tf_model_d_zpk = zpk(tf_model_d);
ceros = tf_model_d_zpk.Z{1};
polos = tf_model_d_zpk.P{1};

%%%%%%%%%%%%%% Mezzz %%%%%%%%%%%%%
% tf_model_d_zpk =zpk([ceros(1) ceros(2) ceros(5)],[polos(3) polos(4) polos(5) polos(6)],1,Tm); %% HPK Mezz
% tf_model_d = tf(tf_model_d_zpk);
% tf_model_d.Variable = 'z^-1';
% %%%%%%%%%%%%%% components causing the undershoot 
% tf_u_zpk =zpk([polos(2)],[ceros(4)],1,Tm); %% HPK Mezz
% tf_u_d = tf(tf_u_zpk);
% tf_u_d.Variable = 'z^-1';
% tf_u = d2c(tf_u_d)
%%%%%%%%%%%%%%

[comp_coeff] = generateFractionalZeroCompensator(ceros(3), 20,0.75);


output_d = filter(tf_model_d.Numerator,tf_model_d.Denominator,circshift(input_data,max_i+circ_start-1));
%output_d = filter(conv([1 -polos(1)],[1 -polos(2)]),[1 -ceros(4)],output_d);
%output_d = filter([1],[1 -ceros(3)],output_d);
stairs(tiempo*1e6,output_d,'LineStyle','-','Marker','.','LineWidth',1)
stairs(tiempo*1e6,circshift(input_data,max_i+circ_start-1)')

set(h,'Position',[100,100,800,600])
title('Estimated discrete response at $F_s$ = 16 ns - FBK', 'Interpreter', 'latex')
xlabel('Time [$\mu$s]', 'Interpreter', 'latex')
ylabel('Amplitude [$\mu$V]', 'Interpreter', 'latex')
legend('SPICE model','Discrete TF with $F_s$ = 16 ns','interpreter','latex','FontSize',16)
set(findall(gcf, 'Type', 'text'), 'Interpreter', 'latex');
set(findall(gcf, 'Type', 'text'), 'FontSize',16);
set(gca, 'FontSize', 16);


num_final = conv(tf_model_d.Numerator,numh);
den_final = conv(tf_model_d.Denominator,denh);
tf_final = tf(num_final,den_final,Tm);
tf_final.Variable = 'z^-1';
tf_final_c = d2c(tf_final);
num_s = tf_final_c.Numerator{1};
den_s = tf_final_c.Denominator{1};

spe_template_struct(number).tf = tf_model_d;
spe_template_struct(number).num = tf_model_d.Numerator;
spe_template_struct(number).den = tf_model_d.Denominator;

save("templates_np02_large_pulses.mat","spe_template_struct")


% syms s t                                                    
% num_s_sym = poly2sym(num_s, s);                              
% den_s_sym = poly2sym(den_s, s);     
% function_time_domain = partfrac(num_s_sym/den_s_sym,s,'FactorMode','full');
% function_time_domain = ilaplace(vpa(function_time_domain));
% function_time_domain = simplify(function_time_domain, 'Steps',10);     
% function_time_domain = collect(function_time_domain, exp(-t));
% 
% figure(3)
% hold on 
% time_domain_eval = zeros(1,length(tiempo));
% 
% for j=1:length(tiempo)
%     t=tiempo(j);
%     %time_domain_eval(i) = subs(function_time_domain);
%     time_domain_eval(j) = 2514867037.4136437389663051224833*exp(-1610617.8327013379902091253611618*t) - exp(t*(- 14487626.798880214422695318879416 + 11699436.426844351086560848059569i))*(1688539916.7274923105093447139397 + 1375282808.2514327759156880933874i) - 6647064.2199279274412108970345592*exp(-4400.1128287438555159342290037279*t) - exp(t*(- 14487626.798880214422695318879416 - 11699436.426844351086560848059569i))*(1688539916.7274923105093447139397 - 1375282808.2514327759156880933874i) + exp(t*(- 18463068.007536083501125653522767 - 51768242.917584646083566030496439i))*(431526946.60362091663291744374459 - 226296947.93588007015805434360433i) + exp(t*(- 18463068.007536083501125653522767 + 51768242.917584646083566030496439i))*(431526946.60362091663291744374459 + 226296947.93588007015805434360433i);
% end
% 
% correction_factor = max(output_d)/max(time_domain_eval);
% time_domain_eval = correction_factor*circshift(time_domain_eval,1513);
% time_domain_eval = time_domain_eval(1513:end);
% time_domain_eval = [zeros(1,1512) time_domain_eval];
% plot(tiempo*1e6,time_domain_eval,'LineWidth',1);


