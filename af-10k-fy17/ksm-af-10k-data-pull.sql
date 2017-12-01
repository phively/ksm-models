-- Build AF 10k dataset
/*
Drop Materialized View mv_af_10k_model
*/
/*
Create Materialized View mv_af_10k_model As
Select *
From af_10k_model
*/

-- Retrieve results
Select *
From mv_af_10k_model
Where rn <= 45000

Select *
From mv_af_10k_model
Where rn > 45000
