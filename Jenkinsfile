pipeline {
   agent any

   stages {
      stage('Git Clone') {
         steps {             
             git url: 'https://github.com/github4swapnil/Pipeline_demo.git'
         }
      }
      stage('Execute Stored Procedure')
      {
          steps{
             
          sh label: '', script: 
             '''for %%G in (*.sql) 
                  DO (echo Executing: "%%G" 
                     sqlcmd -S qacop.ccz8gy1ujvhp.us-east-2.rds.amazonaws.com,1433 -E -U swapniln -P swapnilqacop -i "%%G")
               )
                  '''
          }
      }
   }
}
