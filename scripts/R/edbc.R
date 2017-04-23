# Load libraries
library("mongolite")
library("entropy")
library("C50")
#library("ROCR")

# -- FEATURE SELECTION -- #

   Normalize <- function(x) (x - min(x)) / (max(x) - min(x))

   # Discrete probability distribution
   DPD <- function(v, ...) {
      (count <- table(v, ..., dnn=NULL)) / sum(count)
   }

   # Mutual information
   MI <- function(v1, v2) {
      p = DPD(v1, v2)
      p1 = rowSums(p)
      p2 = colSums(p)
      sum(p*log2(p/(p1%o%p2)), na.rm=TRUE)
   }

   # Symmetric uncertainty
   SU <- function(v1, v2) {
      2 * MI(v1, v2) / (entropy.ChaoShen(v1) + entropy.ChaoShen(v2))
   }

   # Select relevant features
   SF <- function(data) {
      threshold = 0 # 0.0 - 1.0
      su = c()
      for (x in 1:(ncol(data)-1)) {
         su[x] = SU(data[, x], as.numeric(as.factor(data[, ncol(data)])))
      }
      # unitization [0;1]
      su = round(Normalize(su), 1)
      su[length(su) + 1] = threshold + 0.1
      return(which(su > threshold))
   }

   # Irrelevant feature removal
   IFR <- function(data, features) {
      return(data[, features])
   }

# -- PROTOTYPE SELECTION -- #

   # Jarvis-Patric clustering
   JPC <- function(data, class.name, class.values) {
      result = data[0,]
      k = 10
      threshold = 5
      count = k - threshold
      # for each class
      for (x in 1:length(class.values)) {
         for (y in 1:count) {
            assign(paste("cluster", y, sep="_"), data[0,])
         }
         sub = subset(data, data[[class.name]] == class.values[x])
         dist = as.matrix(dist(sub[, -ncol(sub)], method = "euclidean", diag = FALSE, upper = FALSE, p = 2))
         for (y in 1:(nrow(sub) - 1)) {
            distC1 = as.integer(names(sort(dist[y,-y])[1:k]))
            for (z in (y+1):(nrow(sub))) {
               distC2 = as.integer(names(sort(dist[z,-z])[1:k]))
               snn = sum(table(c(distC1, distC2)) == 2)
               if (snn > threshold) {
                  index = snn - threshold
                  clustername = paste("cluster", index, sep="_")
                  cluster = eval(as.name(clustername))
                  if (nrow(merge(sub[y,], cluster)) == 0) {
                     assign(clustername, rbind(cluster, sub[y,]))
                  }
                  if (nrow(merge(sub[z,], cluster)) == 0) {
                     assign(clustername, rbind(cluster, sub[z,]))
                  }
               }
            }
         }
         for (y in 1:count) {
            cluster = eval(as.name(paste("cluster", y, sep="_")))
            if (nrow(cluster) > 0) {
               row = data[0,]
               row[1, ncol(row)] = class.values[x]
               row[1, -ncol(row)] = colMeans(cluster[, -ncol(cluster)])
               result = rbind(result, row)
            }
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

      # Irrelevant feature removal: remove features below relevant threshold
      features = SF(traindata)
      writeLines("~ Irrelevant features selected")
      datasetR = IFR(traindata, features)
      writeLines("~ Train data reduced")

      # Prototype selection: Jarvis-Patric clustering
      datasetP = JPC(datasetR, class.name, class.values)
      writeLines("~ Prototypes selected")

      # Dissimilarity transformation
      datasetD = DT(datasetR, datasetP)
      writeLines("~ Dissimilarity matrix obtained")

      # New data reduction
      datasetRn = IFR(testdata, features)
      writeLines("~ Test data reduced")

      # New data dissimilarity transformation
      datasetDt = DT(datasetRn, datasetP)
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
      cat("~ Results inserted into:", db.name, "-> edbc")

      # close mongo connection
      rm(conn)
   }
   

# -- RUN TESTS -- #
args = commandArgs()
db.name = args[6]

Tests(db.name)
