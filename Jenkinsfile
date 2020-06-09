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
             
           bat label: '', script: '''for %%G in (*.sql) DO (echo Executing: "%%G" 
                sqlcmd -H SwapnilN-MSD1 -E -S . -d QACOP -i "%%G"
               
               )
                  '''
          }
      }
   }
}
