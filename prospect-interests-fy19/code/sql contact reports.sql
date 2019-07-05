Select
  cr.id_number
  , trim(cr.id_number_2)
    As id_number_2
  , trim(cr.contact_date)
    As contact_date
  , ksm_pkg.get_fiscal_year(cr.contact_date)
    As contact_fy
  , cr.description
  , cr.summary
From contact_report cr
Where cr.contact_type = 'V'
