function [gamma, phi_soy, phi_rice] = calculate_moments(soy_yields,rice_yields,...
    soy_acreage,rice_acreage,total_planted_acreage,acreage,...
    soy_calories_per_bushel,rice_calories_per_bushel);

%%% CALCULATE INITIAL MOMENTS %%%
% MOMENT 1 %
soy_calories = soy_yields.*soy_calories_per_bushel;
rice_calories = rice_yields.*rice_calories_per_bushel;

total_calories_produced = sum(soy_acreage.*soy_calories + rice_acreage.*rice_calories);
potential_calories_produced = sum(max(soy_calories,rice_calories).*total_planted_acreage);

gamma = total_calories_produced/potential_calories_produced;

% MOMENT 2 %
actual_soy_bushels = sum(soy_acreage.*soy_yields);

temp_total_planted_acreage = total_planted_acreage;
% note-- we'll need to work only on agricultural land here
temp_empty_acreage = acreage-temp_total_planted_acreage;
temp_empty_acreage_dummy = temp_empty_acreage>0;
temp_max_empty_soy_yield = max(soy_yields(temp_empty_acreage_dummy));
temp_min_used_soy_yield = min(soy_yields(soy_acreage>0));
temp_soy_acreage = soy_acreage;

while temp_max_empty_soy_yield>temp_min_used_soy_yield
    % MARK THE MAXIMUM EMPTY PLOT AND THE MINIMUM USED PLOT %
    temp_max_empty_soy_field = soy_yields == max(soy_yields(temp_empty_acreage_dummy));
    temp_min_used_soy_field = soy_yields == min(soy_yields(temp_soy_acreage>0));
    
    % MOVE ONE ACRE TO THE MAXIMUM EMPTY PLOT FROM THE MINIMUM USED PLOT %
    temp_soy_acreage(temp_min_used_soy_field) = temp_soy_acreage(temp_min_used_soy_field)-1;
    temp_soy_acreage(temp_max_empty_soy_field) = temp_soy_acreage(temp_max_empty_soy_field)+1;
    
    % RECALCULATE EMPTY ACREAGE 
    temp_empty_acreage = acreage-temp_total_planted_acreage;
    temp_empty_acreage_dummy = temp_empty_acreage>0;
    temp_max_empty_soy_yield = max(soy_yields(temp_empty_acreage_dummy));
    temp_min_used_soy_yield = min(soy_yields(temp_soy_acreage>0));
end

potential_soy_bushels = sum(temp_soy_acreage.*soy_yields);

phi_soy = actual_soy_bushels/potential_soy_bushels;


actual_rice_bushels = sum(rice_acreage.*rice_yields);

temp_total_planted_acreage = total_planted_acreage;
temp_empty_acreage = acreage-temp_total_planted_acreage;
temp_empty_acreage_dummy = temp_empty_acreage>0;
temp_max_empty_rice_yield = max(rice_yields(temp_empty_acreage_dummy));
temp_min_used_rice_yield = min(rice_yields(rice_acreage>0));
temp_rice_acreage = rice_acreage;

while temp_max_empty_rice_yield>temp_min_used_rice_yield
    % MARK THE MAXIMUM EMPTY PLOT AND THE MINIMUM USED PLOT % 
    temp_max_empty_rice_field = rice_yields == max(rice_yields(temp_empty_acreage_dummy));
    temp_min_used_rice_field = rice_yields == min(rice_yields(temp_rice_acreage>0));
    
    % MOVE ONE ACRE TO THE MAXIMUM EMPTY PLOT FROM THE MINIMUM USED PLOT %
    temp_rice_acreage(temp_min_used_rice_field) = temp_rice_acreage(temp_min_used_rice_field)-1;
    temp_rice_acreage(temp_max_empty_rice_field) = temp_rice_acreage(temp_max_empty_rice_field)+1;
    
    % RECALCULATE EMPTY ACREAGE 
    temp_empty_acreage = acreage-temp_total_planted_acreage;
    temp_empty_acreage_dummy = temp_empty_acreage>0;
    temp_max_empty_rice_yield = max(rice_yields(temp_empty_acreage_dummy));
    temp_min_used_rice_yield = min(rice_yields(temp_rice_acreage>0));
end

potential_rice_bushels = sum(temp_rice_acreage.*rice_yields);

phi_rice = actual_rice_bushels/potential_rice_bushels;









