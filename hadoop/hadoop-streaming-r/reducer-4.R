#!/opt/apps/intel15/mvapich2_2_1/Rstats/3.2.1/bin/Rscript

word_count <- 0
prev_word <- ""
word=""

#Sys.setlocale('LC_ALL','C')
con <- file("stdin", open = "r")
while (length(line <- readLines(con,n=1,warn = FALSE)) > 0) {
  val=strsplit(line,fixed =TRUE,split="\t",useBytes=T)[[1]]
  word=val[1]
  count=as.integer(val[2])
  if(word!=prev_word){
    if(prev_word!="")   
         cat( sprintf("%s\t%i\n",prev_word,word_count));
    prev_word<-word;
    word_count<-count;
   } else {
    word_count<-word_count+count
  }
}


if(word!="") cat(word,"\t",word_count,"\n",sep="")

close(con)

