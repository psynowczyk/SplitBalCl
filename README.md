# SplitBalCl
A parallel classification method using mapreduce for large imbalanced datasets.

# Table of contents
- [Technical setup](#technical-setup)
- [Data preparation](#data-preparation)

# Technical setup
**CPU**: 2/4 CPUs - Intel® Core™ i7-4510U (2.0 GHz, 3.1 GHz Turbo, 4 MB Cache)<br>
**RAM**: 1 GB DDR3 (1600 MHz)<br>
**HDD**: 290 GB <br>
**OS**: Linux Mint 18 cinamon 64-bit

# Data preparation
Small [dataset](datasets/winequality-white.csv) for test purposes was obtained from [UCI Machine Learning Repository](https://archive.ics.uci.edu/ml/datasets.html)
Replacements of semicolons with commas were necessary in order to import the dataset into mongo data base.
```sh
$ mongoimport --db wine_white --collection quality --type csv --headerline --file datasets/winequality-white.csv
imported 4898 documents
```
Sample
```js
> db.quality.findOne()
{
	"_id" : ObjectId("5846c767eee95f8d05f0b346"),
	"fixed acidity" : 7,
	"volatile acidity" : 0.27,
	"citric acid" : 0.36,
	"residual sugar" : 20.7,
	"chlorides" : 0.045,
	"free sulfur dioxide" : 45,
	"total sulfur dioxide" : 170,
	"density" : 1.001,
	"pH" : 3,
	"sulphates" : 0.45,
	"alcohol" : 8.8,
	"quality" : 6
}
```
