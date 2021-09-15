# Fuzzy match

Testing fuzzy matching techniques on biographic and employment datasets. See also [Many John Smiths](https://github.com/phively/demos/tree/master/many-john-smiths).

HTML rendering:

  * [01 Synthetic data](https://phively.github.io/ksm-models/fuzzy-match-fy21/01%20Synthetic%20data.nb.html) - creating synthetic datasets based on [publicly-available data](https://github.com/phively/ksm-models/tree/master/fuzzy-match-fy21/data)
    * [Randomized 10k biodata - original.csv](https://raw.githubusercontent.com/phively/ksm-models/master/fuzzy-match-fy21/generated%20data/Randomized%2010k%20biodata%20-%20original.csv): uses a probabilistic approach to generate 10,000 fake records
    * [Randomized 10k biodata - scrambled fields.csv](https://raw.githubusercontent.com/phively/ksm-models/master/fuzzy-match-fy21/generated%20data/Randomized%2010k%20biodata%20-%20scrambled%20fields.csv): performed random field-wide deletion, replacement, and swapping on the previous file
    * [Randomized 10k biodata - scrambled fields and typos.csv](https://github.com/phively/ksm-models/blob/master/fuzzy-match-fy21/generated%20data/Randomized%2010k%20biodata%20-%20scrambled%20fields%20and%20typos.csv): random string insertion, deletion, replacement, and transposition on the previous file