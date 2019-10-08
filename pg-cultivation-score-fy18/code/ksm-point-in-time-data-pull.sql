-- Retrieve results
Select *
From point_in_time_model_19future
Where rn <= 36000

-- Next set
Select *
From point_in_time_model_19future
Where rn > 36000
  And rn <= 72000
  
-- Next set
Select *
From point_in_time_model_19future
Where rn > 72000
