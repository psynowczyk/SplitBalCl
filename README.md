# SplitBalCl
A script for parallel classification of vast imbalanced datasets using split balancing method.

# Table of contents
- [Data preparation](#data-preparation)
- [Split balancing](#split-balancing)

# Data preparation
Small [dataset](datasets/yeast6.csv) for test purposes was obtained from [KEEL Data set repository](http://sci2s.ugr.es/keel/imbalanced.php).<br>
Dataset summary:<br>

name | Attributes | Examples | IR
--- | --- | --- | ---
yeast6 | 8 | 1484 | 41.4

Import:
```sh
$ mongoimport --db imbalanced --collection yeast6 --type csv --headerline --file datasets/yeast6.csv
imported 1484 documents
```
Sample:
```js
> db.yeast6.findOne();
{
	"_id" : ObjectId("585154c04529cbc161146d0e"),
	"Mcg" : 0.58,
	"Gvh" : 0.61,
	"Alm" : 0.47,
	"Mit" : 0.13,
	"Erl" : 0.5,
	"Pox" : 0,
	"Vac" : 0.48,
	"Nuc" : 0.22,
	"Class" : "negative"
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
