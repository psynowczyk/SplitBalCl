# args -> [file, database]
# ex. -> $ Rscript scripts/R/dbc.R yeast6

# Load libraries
library("mongolite")
library("entropy")
library("C50")

# -- PROTOTYPE SELECTION -- #

Neighbors <- function(dists, eIdx, k) {
   as.integer(names(sort(dists[eIdx, -eIdx])[1:k]))
}

# Jarvis-Patric clustering
JPC <- function(data, class.name, class.value) {
   result = data[0,]
   sub = subset(data, data[[class.name]] == class.value)
   nrows = nrow(sub)
   opposite.count = nrow(data) - nrows
   ratio = nrows / nrow(data)

   # number of nearest neighbors
   k = floor(ratio * opposite.count)

   # minimal number of shared nearest neighbors, 10% of k
   threshold = floor(k * 0.1)

   # number of clusters ~ prototypes
   clusters.count = k - threshold

   # pre-allocate an empty list for clusters
   clusters = vector("list", clusters.count)
   
   # euclidean distance matrix
   dists = as.matrix(dist(sub[, -ncol(sub)], method = "euclidean", diag = FALSE, upper = FALSE, p = 2))
   
   progress = 0
   all = (nrows * (nrows-1)) / 2
   cat("~ JPC (", class.value, ") 0%", sep = "")

   for (y in 1:(nrows - 1)) {
      step = (y * nrows) / 2
      progress.new = round(step / all * 100)
      if (progress != progress.new) {
         cat("\r~ JPC (", class.value, ") ", progress.new, "%", sep = "")
         progress = progress.new
      }
      neighbors.e1 = Neighbors(dists, y, k)
      for (z in (y+1):nrows) {
         neighbors.e2 = Neighbors(dists, z, k)
         snn = sum(table(c(neighbors.e1, neighbors.e2)) == 2)
         if (snn > threshold) {
            cluster.id = snn - threshold
            if (!(y %in% clusters[[cluster.id]])) {
               clusters[[cluster.id]] = c(clusters[[cluster.id]], y)
            }
            if (!(z %in% clusters[[cluster.id]])) {
               clusters[[cluster.id]] = c(clusters[[cluster.id]], z)
            }
         }
      }
   }
   cat("\n", sep = "")

   # compute prototypes: prototype_x = mean(cluster_x)
   for (y in 1:clusters.count) {
      cluster = sub[clusters[[y]],]
      if (nrow(cluster) > 0) {
         row = data[0,]
         row[1, ncol(row)] = class.value
         row[1, -ncol(row)] = colMeans(cluster[, -ncol(cluster)])
         result = rbind(result, row)
      }
   }

   return(result)
}

# -- DISSIMILARITY TRANSFORMATION -- #

EucDist <- function(x1, x2) sqrt(sum((x1 - x2) ^ 2))

DT <- function(data, prototypes) {
   result = data.frame()
   for (x in 1:nrow(data)) {
      for (y in 1:nrow(prototypes)) {
         result[x, y] = EucDist(data[x, -ncol(data)], prototypes[y, -ncol(prototypes)])
      }
      result[x, (nrow(prototypes) + 1)] = as.character(data[x, ncol(data)])
   }
   return(result)
}

# -- TESTS -- #

Tests <- function(db.name) {

   split = c("train", "test")

   # open mongo connection
   collname = paste(db.name, "_", split[2], sep="")
   conn = mongo(collname, db.name)
   testdata = conn$find()
   class.number = ncol(testdata)
   class.name = colnames(testdata)[class.number]
   class.values = sort(conn$distinct(class.name))
   collname = paste(db.name, "_", split[1], sep="")
   conn = mongo(collname, db.name)
   traindata = conn$find()

   # Prototype selection: Jarvis-Patric clustering
   datasetP = JPC(traindata, class.name, class.values[1])
   datasetP = rbind(datasetP, JPC(traindata, class.name, class.values[2]))
   writeLines("~ Prototypes selected")

   # Dissimilarity transformation
   datasetD = DT(traindata, datasetP)
   writeLines("~ Dissimilarity matrix obtained")

   # New data dissimilarity transformation
   datasetDt = DT(testdata, datasetP)
   writeLines("~ Test data dissimilarity matrix obtained")

   # Build model & get probabilities
   model = C5.0(x = datasetD[, -ncol(datasetD)], y = as.factor(datasetD[, ncol(datasetD)]))
   writeLines("~ Model built")
   probs = predict(model, datasetDt, type = "prob")
   writeLines("~ Predictions obtained")
   
   # Insert results into database
   conn = mongo("edbc", db.name)
   if(conn$count() > 0) conn$drop()
   conn$insert(as.data.frame(probs))
   cat("~ Results inserted into:", db.name, "-> edbc\n")

   # close mongo connection
   rm(conn)
}
   

# -- RUN TESTS -- #
args = commandArgs()
db.name = args[6]

Tests(db.name)
