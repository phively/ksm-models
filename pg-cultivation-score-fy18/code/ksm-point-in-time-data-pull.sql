-- Retrieve results
Select *
From point_in_time_model
Where rn <= 45000

-- Second half
Select *
From point_in_time_model
Where rn > 45000
