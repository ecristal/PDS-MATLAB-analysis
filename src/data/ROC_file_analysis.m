function [estimated_threshold_position, pos_accuracy, pos_tpr, pos_fpr, pauc,pauc_n, gini] = ROC_file_analysis(roc,threshold_level,plot_data)
data = roc{threshold_level}.data;
len = length(data);
acc = zeros(1,len);
tpr = zeros(1,len);
fpr = zeros(1,len);
for i=1:len
    acc(i) = data{i}.accuracy;
    tpr(i) = data{i}.sensitivity;
    fpr(i) = 1-data{i}.specificity;
end
init_th = data{1}.virtual_trigger_pos;
step_th = data{2}.virtual_trigger_pos-data{1}.virtual_trigger_pos;
last_th = data{len}.virtual_trigger_pos;
threshold = init_th:step_th:last_th;
[~, i_pos] = max(acc);
estimated_threshold_position = threshold(i_pos);
pos_accuracy = acc(i_pos);
pos_tpr = tpr(i_pos);
pos_fpr = fpr(i_pos);
tpr = tpr(~isnan(fpr));
fpr = fpr(~isnan(fpr));
[~,min_fpr_pos] = min(fpr);

[fpr, index_i] = sort(fpr);
tpr = tpr(index_i);

pauc = trapz(fpr(1:end),tpr(1:end));
%pauc = pauc + trapz(fpr(1:min_fpr_pos),tpr(1:min_fpr_pos));
M_pauc = fpr(end) - fpr(1);
m_pauc = 0.5*(fpr(end) - fpr(1))*(fpr(end) + fpr(1));
pauc_n = 0.5*( 1 + (pauc - m_pauc)/(M_pauc-m_pauc));
gini = (pauc_n - 0.5)/0.5;
if(plot_data)
    figure(1)
    plot(threshold,acc*100)
    hold on 
    %plot(threshold(1:end-1),diff(acc))
    xline(estimated_threshold_position,'r-.')
    xlabel('ADU','Interpreter','latex')
    ylabel('Accuracy [$\%$]','Interpreter','latex')
    grid on 
    title('Accuracy vs. threshold','Interpreter','latex')
    figure(2)
    stairs(fpr,tpr)
    xlabel('False Positive Rate','Interpreter','latex')
    ylabel('True Positive Rate','Interpreter','latex')
    grid on 
    title('ROC curve','Interpreter','latex')
end
end