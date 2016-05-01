#!/opt/apps/intel15/mvapich2_2_1/Rstats/3.2.1/bin/Rscript

# mapper.R - Wordcount program in R
# script for Mapper (R-Hadoop integration)

trimWhiteSpace <- function(line) gsub("^\\s+|\\s+$", "", line)
#splitIntoWords <- function(line) unlist(strsplit(line, " "))
splitIntoWords <- function(line) strsplit(line, fixed=T, split=" ")[[1]]

#Sys.setlocale('LC_ALL','C') 
## **** could wo with a single readLines or in blocks
con <- file("stdin", open = "r")
while (length(line <- readLines(con, n = 1, warn = FALSE)) > 0) {
  #line <- gsub("[^[:alnum:]///' ]", "", line)
  line <-gsub("\\s+"," ", trimWhiteSpace(line))
  words <-as.character(splitIntoWords(line))

# cat(paste(words, "\t1\n", sep=""), sep="")

  for (w in words)
      cat(w, "\t1\n", sep="")
}

close(con)

