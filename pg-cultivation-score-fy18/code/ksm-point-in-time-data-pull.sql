-- Build point-in-time dataset
/*
Drop Materialized View mv_point_in_time_model
*/
/*
Create Materialized View mv_point_in_time_model As
Select *
From point_in_time_model
*/

-- Retrieve results
Select *
From mv_point_in_time_model
Where rn <= 45000

Select *
From mv_point_in_time_model
Where rn > 45000
