# SplitBalCl
A script for parallel classification of vast imbalanced datasets using split balancing method.

# Table of contents
- [Environment](#environment)
- [Data preparation](#data-preparation)
- [Split balancing](#split-balancing)

# Environment
Requirements:
* openssl and Cyrus SASL
* MongoDB
* R + packages: rJava, mongolite, C50
```sh
apt-get install libsasl2-dev
apt-get install r-base-core
apt-get install r-cran-rjava
```
```r
install.packages("mongolite")
install.packages("C50", repos="http://R-Forge.R-project.org")
```

# Data preparation
### Dataset
Small [dataset](datasets/yeast6.csv) for test purposes was obtained from [KEEL Data set repository](http://sci2s.ugr.es/keel/imbalanced.php).<br>

**Dataset summary**

name | Attributes | Examples | Imbalance Ratio
--- | --- | --- | ---
yeast6 | 8 | 1484 | 41.4

**Import**
```sh
$ mongoimport --db imbalanced --collection yeast6 --type csv --headerline --file datasets/yeast6.csv
imported 1484 documents
```

**Sample**
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
### Test & Train subsets
In order to measure classification accuracy a test and train subsets are required. Those subsets are generated from original dataset by splitting it into two subsets. Following [R script](scripts/R/generate_db.R) is employed to achieve this task.<br>

**Usage**
```sh
$ Rscript generate_db.R imbalanced yeast6 Class
```

**Arguments**

1. R script location
2. name of database
3. name of collection
4. name of class

**Script**
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
**Description**<br>
A split balancing method implementation [R script](scripts/R/splitbal_binary.R).<br>

**Usage**
```sh
$ Rscript splitbal_binary.R imbalanced yeast6 Class 1 mongo
```

**Arguments**

1. R script location
2. name of database
3. name of collection
4. name of class
5. bin number [1...x=C1/C2]
6. output type
  * mongo - inserts result data into database as new collection: collection_result_bin
  * file - writes result data into file: results/collection_result_bin
  * console - prints result data into console

**Script**
```r
 # args -> [file, database, collection, class name, bin number (1...x=C1/C2), output (mongo, file, console)]
 # ex. -> $ Rscript splitbal_binary.R imbalanced yeast6 Class 1 mongo

 # load libraries
library(mongolite)
library(C50)

 # initial variables
args = commandArgs()
db.name = args[6]
db.collection = args[7]
class.name = args[8]
bin.number = as.numeric(args[9])
output = args[10]
if (bin.number <= 0) bin.number = 1
calg = "C5.0"
split = c("train", "test")

 # open mongo connection
collname = paste(db.collection, "_", split[2], sep="")
conn = mongo(collname, db.name)
testdata = conn$find()
collname = paste(db.collection, "_", split[1], sep="")
conn = mongo(collname, db.name)

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
if (bin.number > bin.count) bin.number = bin.count
limit = class.sizes[2] # 35
skip = ((bin.number - 1) * limit) # 0, 35, 70, ...+35
if (bin.number == bin.count) limit = class.sizes[1] - skip

 # read collection and build bin
query = paste('{"', class.name, '": "', class.values[1], '"}', sep="")
bin.negative = conn$find(query, skip=skip, limit=limit)
bin = rbind(bin.negative, bin.positive)

 # classify
if (calg == "C5.0") {
	model = C5.0(x = bin[, -ncol(bin)], y = as.factor(bin[, ncol(bin)]))
	probs = predict(model, testdata, type = "prob")
}

 # return result
collname = paste(db.collection, "_result_", bin.number, sep="")
filename = paste("results/", collname, sep="")
if (output == "file") {
	if (!dir.exists("results/")) dir.create("results/", mode = "0777")
	write(t(probs), file=filename, ncolumns=2)
} else {
	if (output == "console") {
		writeLines("RESULTS")
		print(probs)
	} else {
		conn = mongo(collname, db.name)
		if(conn$count() > 0) conn$drop()
		conn$insert(as.data.frame(probs))
	}
}

 # close mongo connection
rm(conn)
```
