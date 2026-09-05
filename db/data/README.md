# Dataset

`bank_sqlite.db.tar.xz` is the [Synthetic Banking Dataset](https://www.kaggle.com/datasets/akrambelha/synthetic-banking-dataset-csv-sql-sqlite)
by akrambelha, published on Kaggle under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/),
repackaged unchanged as one xz-compressed SQLite file (32 MB compressed, 107 MB extracted):
50,000 customers, 75,000 accounts, 100,000 cards, 5,000 merchants, 500 branches, 30,000 loans,
and 1,000,000 transactions. The data is fully synthetic; it describes no real person or account.

`bin/rails banking:setup` extracts it into `tmp/banking/` and copies every table into the app
database. Nothing else reads this file.
