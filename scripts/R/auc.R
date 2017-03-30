# args -> [file, database]
 # ex. -> $ Rscript scripts/R/ensemble.R yeast6

 # load libraries
library("mongolite")
library("ROCR")

 # initial variables
args = commandArgs()
db.name = args[6];
conn = mongo(paste(db.name, "_test", sep=""), db.name)
testdata = conn$find()
conn = mongo("ens_1", db.name)
ens = conn$find()

 # Confidence
Conf <- function(data, prob) {
   result = data.frame()
   labels = as.numeric(as.factor(data[, ncol(data)]))-1
   for (x in 1:nrow(data)) {
      if (!is.vector(prob)) result = rbind(result, c(as.numeric(prob[x, 2]), labels[x]))
      if (is.vector(prob)) result = rbind(result, c(as.numeric(prob[x]), labels[x]))
   }
   return(result)
}

 # compute AUC
conf = Conf(testdata, ens)
pred = prediction(conf[, 1], conf[, 2])
perf = performance(pred, "auc")
auc = as.numeric(slot(perf, "y.values")[1])

 # return result
conn = mongo("auc", db.name)
#if (conn$count() > 0) conn$drop()
conn$insert(as.data.frame(auc))

 # close mongo connection
rm(conn)
