-- Retrieve results
Select *
From point_in_time_model_2019
Where rn <= 36000

-- Next set
Select *
From point_in_time_model_2019
Where rn > 36000
  And rn <= 72000
  
-- Next set
Select *
From point_in_time_model_2019
Where rn > 72000
