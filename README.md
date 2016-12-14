# SplitBalCl
A script for parallel classification of vast imbalanced datasets using split balancing method.

# Table of contents
- [Data preparation](#data-preparation)
- [Split balancing](#split-balancing)

# Data preparation
Small [dataset](datasets/yeast6.csv) for test purposes was obtained from [KEEL Data set repository](http://sci2s.ugr.es/keel/imbalanced.php).<br>
Dataset summary:<br>

name | Attributes | Examples | Imbalance Ratio
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
In order to measure classification accuracy a train and test datasets are required. Those datasets are generated from original dataset by splitting it into two subsets. Following [R script](scripts/R/generate_db.R) is employed to achieve this task.<br>
Usage:
```sh
$ Rscript generate_db.R database collection class
```
Script:
```r
 # args -> [file, database, collection, class name]
 # ex. -> $ Rscript generate_db.R imbalanced yeast6 Class

 # load libraries
library(mongolite)

 # initial variables
args = commandArgs()
db.name = args[6]
db.collection = args[7]
class.name = args[8]
ratio = 0.7
split = c("train", "test")
data.train = data.frame()
data.test = data.frame()

 # open mongo connection
conn = mongo(db.collection, db.name)

 # get test and train subsets
class.values = sort(conn$distinct(class.name)) # "negative", "positive"
for (x in 1:length(class.values)) {
	query = paste('{"', class.name, '": "', class.values[x], '"}', sep="")
	data = conn$find(query)
	size = round(nrow(data) * 0.7)	
	rand = sample(1:nrow(data), size)
	data.train = rbind(data.train, data[rand,])
	data.test = rbind(data.test, data[-rand,])
}

 # insert test and train subsets into database
for (x in 1:length(split)) {
	collname = paste(db.collection, "_", split[x], sep="")
	conn = mongo(collname, db.name)
	if(conn$count() > 0) conn$drop()
	data = eval(as.name(paste("data.", split[x], sep="")))
	conn$insert(data)
}

 # close mongo connection
rm(conn)
```

# Split balancing
A split balancing method implemented in [R script](scripts/R/splitbal_binary.R).<br>
Usage:
```sh
$ Rscript splitbal.R database collection class bin
```
Script:
```r
 # args -> [file, database, train collection, test collection, class name, bin number]
 # ex. -> $ Rscript splitbal_binary.R imbalanced yeast6_train yeast6_test Class 1

 # load libraries
library(mongolite)

 # initial variables
args = commandArgs()
db.name = args[6]
db.coll_train = args[7]
db.coll_test = args[8]
class.name = args[9]
bin.number = as.numeric(args[10])

 # open mongo connection
conn = mongo(db.coll_test, db.name)
testdata = conn$find()
conn = mongo(db.coll_train, db.name)

 # find all class values and sizes
class.values = sort(conn$distinct(class.name)) # "negative", "positive"
class.sizes = c(rep(0, length(class.values)))  # 1449, 35
for (x in 1:length(class.values)) {
	query = paste('{"', class.name, '": "', class.values[x], '"}', sep="")
	class.sizes[x] = conn$count(query)
}
bin.positive = conn$find(query)

 # compute bin range
bin.count = floor(class.sizes[1] / class.sizes[2]) # 41
limit = class.sizes[2] # 35
skip = ((bin.number - 1) * limit) # 0, 35, 70, ...+35
if (bin.number == bin.count) {
	limit = class.sizes[1] - skip
}

 # read collection and build bin
query = paste('{"', class.name, '": "', class.values[1], '"}', sep="")
bin.negative = conn$find(query, skip=skip, limit=limit)
bin = rbind(bin.negative, bin.positive)

 # classify
 #probs = matrix(c(0), nrow = nrow(datasetTe), ncol = length(class))

 # close mongo connection
rm(conn)

```
