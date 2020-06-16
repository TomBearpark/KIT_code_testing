clear

%%% PARAMETERS %%%
a = 1000;
b = 0;

acreage = [100; 100; 100];

soy_calories_per_bushel  = 25;
rice_calories_per_bushel = 15;

current_soy_yields  = [10; 20; 15];
current_rice_yields = [20; 10; 15];

%just testing what happens when you multiply by some linear factor
current_soy_yields = current_soy_yields.*a + b.*ones(3,1);
current_rice_yields = current_rice_yields.*a + b.*ones(3,1);

current_soy_calories  = current_soy_yields.*soy_calories_per_bushel;
current_rice_calories = current_rice_yields.*rice_calories_per_bushel;

% this comes form cropped area raster for t_0
current_soy_acreage  = [40; 70; 0];
current_rice_acreage = [60; 30; 0];
current_total_planted_acreage = current_soy_acreage+current_rice_acreage;

%%% CALCULATE INITIAL SET OF MOMENTS %%%
[gamma, phi_soy, phi_rice] = calculate_moments(current_soy_yields,current_rice_yields,...
    current_soy_acreage,current_rice_acreage,current_total_planted_acreage,acreage,...
    soy_calories_per_bushel,rice_calories_per_bushel);

%%% CLIMATE CHANGE IMPACTS %%%
% note losses are 1 minus the value in these matrices
future_soy_yield_shocks  = [0.5; 0.8; 1];
future_rice_yield_shocks = [0.9; 0.6; 1];

future_soy_yields  = current_soy_yields.*future_soy_yield_shocks;
future_rice_yields = current_rice_yields.*future_rice_yield_shocks;

future_soy_calories  = future_soy_yields.*soy_calories_per_bushel;
future_rice_calories = future_rice_yields.*rice_calories_per_bushel;

%%% CALCULATE NEW SET OF MOMENTS %%%
[gamma_temp, phi_soy_temp, phi_rice_temp] = calculate_moments(future_soy_yields,future_rice_yields,...
    current_soy_acreage,current_rice_acreage,current_total_planted_acreage,acreage,...
    soy_calories_per_bushel,rice_calories_per_bushel);

%%% ITERATE TO MAKE PHI'S HOLD %%%
temp_total_planted_acreage = current_total_planted_acreage;
temp_soy_acreage  = current_soy_acreage;
temp_rice_acreage = current_rice_acreage;
phi_rice_distance = -100;
phi_soy_distance  = -100;

% from here on, we are reallocating to make the new moments match the old moment
while phi_rice_distance<0 || phi_soy_distance<0
    
    %%% MARK MAX EMPTY FIELD AND MIN USED FIELD 
    temp_empty_acreage = acreage-temp_total_planted_acreage;
    temp_empty_acreage_dummy = temp_empty_acreage>0;
    
    temp_max_empty_soy_field = future_soy_yields == max(future_soy_yields(temp_empty_acreage_dummy));
    temp_min_used_soy_field = future_soy_yields == min(future_soy_yields(temp_soy_acreage>0));

    temp_max_empty_rice_field = future_rice_yields == max(future_rice_yields(temp_empty_acreage_dummy));
    temp_min_used_rice_field = future_rice_yields == min(future_rice_yields(temp_rice_acreage>0));
    
    %%% MOVE ONE ACRE OF SOY AND ONE ACRE OF RICE FROM THE LOWEST USED
    %%% FIELD TO THE HIGHEST UNUSED FIELD
    if phi_soy_distance < 0
    temp_soy_acreage(temp_min_used_soy_field) = temp_soy_acreage(temp_min_used_soy_field)-1;
    temp_soy_acreage(temp_max_empty_soy_field) = temp_soy_acreage(temp_max_empty_soy_field)+1;
    end
    if phi_rice_distance < 0
    temp_rice_acreage(temp_min_used_rice_field) = temp_rice_acreage(temp_min_used_rice_field)-1;
    temp_rice_acreage(temp_max_empty_rice_field) = temp_rice_acreage(temp_max_empty_rice_field)+1;
    end
    temp_total_planted_acreage = temp_soy_acreage+temp_rice_acreage;
    
    [gamma_temp, phi_soy_temp, phi_rice_temp] = calculate_moments(future_soy_yields,future_rice_yields,...
    temp_soy_acreage,temp_rice_acreage,temp_total_planted_acreage,acreage,...
    soy_calories_per_bushel,rice_calories_per_bushel);

    phi_soy_distance = phi_soy_temp-phi_soy;
    phi_rice_distance = phi_rice_temp-phi_rice;
    
end

future_soy_acreage = temp_soy_acreage;
future_rice_acreage = temp_rice_acreage;

current_total_calories = sum(current_soy_acreage.*current_soy_calories+...
                                        current_rice_acreage.*current_rice_calories);
future_total_calories_no_reallocation = sum(current_soy_acreage.*future_soy_calories+...
                                        current_rice_acreage.*future_rice_calories);
future_total_calories_with_reallocation = sum(future_soy_acreage.*future_soy_calories+...
                                        future_rice_acreage.*future_rice_calories);


calorie_damages_no_reallocation = (future_total_calories_no_reallocation-current_total_calories)./(current_total_calories);
calorie_damages_with_reallocation = (future_total_calories_with_reallocation-current_total_calories)./(current_total_calories);

% 
% hold on
% bar([current_rice_acreage current_soy_acreage])
% set(gcf,'color','w');
% ylim([0 100]);
% xticks([1 2 3]);
% xlabel('Field','FontSize',18)
% ylabel('Acreage','FontSize',18)
% legend('Rice','Soy','FontSize',18)
% saveas(gcf,'current_acreage.png')
% hold off
% 
% hold on
% bar([current_rice_yields current_soy_yields])
% set(gcf,'color','w');
% ylim([0 30]);
% xticks([1 2 3]);
% xlabel('Field','FontSize',18)
% ylabel('Yield (in bushels)','FontSize',18)
% legend('Rice','Soy','FontSize',18)
% saveas(gcf,'current_yields.png')
% hold off
% 
% hold on
% bar([current_rice_calories current_soy_calories])
% set(gcf,'color','w');
% ylim([0 600]);
% xticks([1 2 3]);
% xlabel('Field','FontSize',18)
% ylabel('Calories (Yield X Calories/Bushel)','FontSize',18)
% legend('Rice','Soy','FontSize',18)
% saveas(gcf,'current_calories.png')
% hold off
% 
% hold on
% bar([future_rice_yield_shocks future_soy_yield_shocks])
% set(gcf,'color','w');
% ylim([0 2]);
% xticks([1 2 3]);
% xlabel('Field','FontSize',18)
% ylabel('Future Yield / Current Yield','FontSize',18)
% legend('Rice','Soy','FontSize',18)
% saveas(gcf,'climate_shocks.png')
% hold off
% 
% hold on
% bar([future_rice_acreage future_soy_acreage])
% set(gcf,'color','w');
% ylim([0 100]);
% xticks([1 2 3]);
% xlabel('Field','FontSize',18)
% ylabel('Acreage','FontSize',18)
% legend('Rice','Soy','FontSize',18)
% saveas(gcf,'future_acreage.png')
% hold off
% 
% 
% 
% 
% 
