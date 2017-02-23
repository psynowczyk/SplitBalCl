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
$ Rscript scripts/R/generate_db.R imbalanced yeast6 Class
```

**Arguments**

1. R script location
2. name of database
3. name of collection
4. name of class

# Split balancing
**Description**<br>
A split balancing method implementation [R script](scripts/R/splitbal_binary.R).<br>

**Usage**
```sh
$ Rscript scripts/R/splitbal_binary.R imbalanced yeast6 Class 1 mongo
```

**Arguments**

1. R script location
2. name of database
3. name of collection
4. name of class
5. bin number [1...x=C1/C2]
6. output type
  * mongo - inserts data into database: collection_result_bin & collection_mean_bin
  * file - writes data into file: results/collection/collection_result_bin & collection_mean_bin
  * console - prints data into console

# Results ensemble
**Description**<br>
Once all predictions are delivered two ensemble methods (MaxDistance, SumDistance) are employed to combine them [R script](scripts/R/ensemble.R).<br>

**Usage**
```sh
$ Rscript scripts/R/ensemble.R imbalanced yeast6 mongo mongo
```

**Arguments**

1. R script location
2. name of database
3. name of collection / file prefix
4. input type
  * mongo - read results from database
  * file - read results from files
5. output type
  * mongo - inserts ensemble data into database as new collection: collection_ensemble
  * file - writes ensemble data into file: results/collection/collection_ensemble
  * console - prints ensemble data into console

**Results**

1. Predictions ensabmle
  * data type: a matrix of predictions after ensabmle process
  * schema: [P1R1 P2R1 ... P1Rn P2Rn], P - probability, R - ensemble rule
  * data sample:
```sh
$ head results/yeast6/yeast6_ensemble 

0.4129194 0.07327571 0.8249341 0.1465514
0.3846482 0.06583408 0.7683319 0.1316682
0.4235479 0.07236825 0.8442176 0.1447365
0.4074153 0.06836955 0.8114674 0.1367391
0.4171966 0.07438938 0.8339174 0.1487788
0.4119431 0.07359854 0.8231136 0.1471971
0.4222198 0.07519196 0.8427968 0.1503839
0.4121872 0.07314196 0.821909 0.1462839
0.4001976 0.06929426 0.7992559 0.1385885
0.4164431 0.07694662 0.8323568 0.1538932

```
2. Ensemble rules performance
  * data type: area under curve (AUC)
  * schema: [AUC-R1 ... AUC-Rn], R - ensemble rule
  * data sample:
```sh
"MaxDistance" "SumDistance"
0.931243469174505 0.931452455590388
```
