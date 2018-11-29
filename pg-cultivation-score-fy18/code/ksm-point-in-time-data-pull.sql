-- Retrieve results
Select *
From point_in_time_model
Where rn <= 47000

-- Second half
Select *
From point_in_time_model
Where rn > 47000
