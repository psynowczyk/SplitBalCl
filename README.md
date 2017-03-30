# SplitBalCl
A script for parallel classification of vast imbalanced datasets using split balancing method.

# Table of contents
- [Environment](#environment)
- [Data preparation](#data-preparation)
- [Split balancing](#split-balancing)

# Environment
Requirements:
* openssl and Cyrus SASL
```sh
apt-get install libsasl2-dev
```
* MongoDB
```sh
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6

echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list

sudo apt-get update
sudo apt-get install -y mongodb-org

```
* R + packages: rJava, mongolite, C50, ROCR
```sh
apt-get install r-base-core
apt-get install r-cran-rjava
apt-get install r-cran-rocr
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
$ mongoimport --db yeast6 --collection yeast6 --type csv --headerline --file datasets/yeast6.csv

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
$ Rscript scripts/R/generate_db.R yeast6
```

**Arguments**

1. R script location
2. name of database

**Output**

"train" and "test" database collections

# Split balancing
**Description**<br>
A parallel split balancing method implementation [R script](scripts/R/splitbal_binary.R).<br>

**Usage**
```sh
$ Rscript scripts/R/splitbal_binary.R yeast6 1
```

**Arguments**

1. R script location
2. name of database
3. bin number [1...x=C1/C2]

**Output**

database collection: result_{#bin}

**Sample**
```js
> db.result_1.findOne();
{
  "_id" : ObjectId("58dce39dbfdeee25f06c0351"),
  "negative" : 0.596274556,
  "positive" : 0.066594659
}
```

# Results ensemble
**Description**<br>
Once predictions are delivered ensemble method can be applied (max, min, sum, pro) [R script](scripts/R/ensemble.R).<br>

**Usage**
```sh
$ Rscript scripts/R/ensemble.R yeast6 1 2 sum
```

**Arguments**

1. R script location
2. name of database
3. predictions subset number
4. predictions subset number
5. ensemble strategy
  * max: maximum classification probability
  * min: minimum classification probability
  * sum: summation of classification probability
  * pro: product of classification probability

**Output**

database collection: ens_{#1 given predictions subset number}

**Sample**
```js
> db.ens_1.findOne();
{
  "_id" : ObjectId("58dd112abfdeee149d1a8451"),
  "negative" : 1.339600045,
  "positive" : 0.791029411
}
```

# Classification performance
**Description**<br>
In order to measure classification performance following [R script](scripts/R/auc.R) is employed, which compute an area under curve (AUC).<br>

**Usage**
```sh
$ Rscript scripts/R/auc.R yeast6
```

**Arguments**

1. R script location
2. name of database

**Output**

database collection (new or insertion): auc

**Sample**
```js
> db.auc.findOne();
{ "_id" : ObjectId("58dd14f8bfdeee19321f9761"), "auc" : 0.894879833 }
```
