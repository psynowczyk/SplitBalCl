# SplitBalCl
A script for parallel classification of vast imbalanced datasets using split balancing method.

# Table of contents
- [Data preparation](#data-preparation)
- [Split balancing](#split-balancing)

# Data preparation
Small [dataset](datasets/winequality-white.csv) for test purposes was obtained from [UCI Machine Learning Repository](https://archive.ics.uci.edu/ml/datasets.html).<br>
Replacements of semicolons with commas were necessary in order to import the dataset into mongo data base.<br>
Dataset class summary:<br>
| quality  | count |
|----------|-------|
| 3        | 20    |
| 4        | 163   |
| 5        | 1457  |
| 6        | 2198  |
| 7        | 880   |
| 8        | 175   |
| 9        | 5     |

Import:
```sh
$ mongoimport --db wine_white --collection quality --type csv --headerline --file datasets/winequality-white.csv
imported 4898 documents
```
Sample:
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

# Split balancing
A split balancing method implemented in [R script](scripts/R/splitbal.R).<br>
Usage:
```sh
$ Rscript splitbal.R database collection class bin
```
Script:
```r
 # args -> [database, collection, className, binNumber]
 # ex. -> $ Rscript splitbal.R wine_white quality quality 1

 # load libraries
library(mongolite)

 # initial variables
args = commandArgs()
database = args[6]
collection = args[7]
className = args[8]
binNumber = as.numeric(args[9])

 # open mongo connection
conn = mongo(collection, database)

 # find all class values and sizes
classValues = sort(conn$distinct(className))
classSizes = c(rep(0, length(classValues)))
for (x in 1:length(classValues)) {
	query = paste('{"', className, '": ', classValues[x], '}', sep="")
	classSizes[x] = conn$count(query)
}

 # TODO:
  # compare class sizes in order to proceed with bin creation process
  # compute bins count and index range

 # read collection
 #dataset = mongo$find('{"foo": "bar"}', skip=skip, limit=limit)

 # close mongo connection
rm(conn)

```
