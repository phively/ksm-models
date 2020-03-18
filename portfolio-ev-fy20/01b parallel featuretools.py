# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

# Imports

import pandas as pd
import featuretools as ft

# Load the data

degree = pd.read_excel(
    r'C:\Users\Paul\Documents\github\ksm-models\portfolio-ev-fy20\data\2020-02-21 entity committee test data.xlsx'
    , sheet_name = 'Select v_entity_ksm_degrees (1)'
    )

committee = pd.read_excel(
    r'C:\Users\Paul\Documents\github\ksm-models\portfolio-ev-fy20\data\2020-02-21 entity committee test data.xlsx'
    , sheet_name = 'Select v_nu_committees (2)'
    )

# Set up the entity set

py_es = ft.EntitySet(id = 'catracks')

# Add degree
py_es = py_es.entity_from_dataframe(
  entity_id = 'degree'
  , dataframe = degree
  , index = 'ID_NUMBER'
)

# Add committee
py_es.entity_from_dataframe(
  entity_id = 'committee'
  # r.committee references committee in the R session; pretty cool!
  , dataframe = committee
  , make_index = True
  , index = 'committee_idx'
)

# Add relationships
py_es = py_es.add_relationship(
  ft.Relationship(
    py_es['degree']['ID_NUMBER']
    , py_es['committee']['ID_NUMBER']
  )
)

# Check results
print(py_es)

# Single worker
feature_matrix, feature_defs = ft.dfs(
  entityset = py_es
  , target_entity = 'degree'
  , agg_primitives = ['count', 'sum', 'std', 'last']
  , trans_primitives = ['month', 'year']
  , max_depth = 2
  , verbose = True
)
# 14 seconds elapsed!

# 1 workers
feature_matrix2, feature_defs = ft.dfs(
  entityset = py_es
  , target_entity = 'degree'
  , agg_primitives = ['count', 'sum', 'std', 'last']
  , trans_primitives = ['month', 'year']
  , max_depth = 2
  , n_jobs = 1
  , verbose = True
)
# 0 seconds to process data
# 14 seconds to compute features

# 2 workers
feature_matrix2, feature_defs = ft.dfs(
  entityset = py_es
  , target_entity = 'degree'
  , agg_primitives = ['count', 'sum', 'std', 'last']
  , trans_primitives = ['month', 'year']
  , max_depth = 2
  , n_jobs = 2
  , verbose = True
)
# 64 seconds to process data
# 11 seconds to compute features

# 3 workers
feature_matrix2, feature_defs = ft.dfs(
  entityset = py_es
  , target_entity = 'degree'
  , agg_primitives = ['count', 'sum', 'std', 'last']
  , trans_primitives = ['month', 'year']
  , max_depth = 2
  , n_jobs = 3
  , verbose = True
)
# 63 seconds to process data
# 9 seconds to compute features

# 4 workers
feature_matrix3, feature_defs = ft.dfs(
  entityset = py_es
  , target_entity = 'degree'
  , agg_primitives = ['count', 'sum', 'std', 'last']
  , trans_primitives = ['month', 'year']
  , max_depth = 2
  , n_jobs = 4
  , verbose = True
)
# 90 seconds to process data
# 8 seconds to compute features

# 6 workers
feature_matrix3, feature_defs = ft.dfs(
  entityset = py_es
  , target_entity = 'degree'
  , agg_primitives = ['count', 'sum', 'std', 'last']
  , trans_primitives = ['month', 'year']
  , max_depth = 2
  , n_jobs = 6
  , verbose = True
)
# 91 seconds to process data
# 6 seconds to compute features

# 8 workers
feature_matrix3, feature_defs = ft.dfs(
  entityset = py_es
  , target_entity = 'degree'
  , agg_primitives = ['count', 'sum', 'std', 'last']
  , trans_primitives = ['month', 'year']
  , max_depth = 2
  , n_jobs = 8
  , verbose = True
)
# 105 seconds to process data
# 6 seconds to compute features