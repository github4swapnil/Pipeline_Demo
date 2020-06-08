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
              
             sh label: '', script: '''for %%G in (*.sql) DO (echo Executing: "%%G" >> output.txt
sqlcmd -H 103.87.29.229 -E -S . -d QACOP -i "%%G" >> output.txt
echo --------------------------------------------- >> output.txt
)
'''
          }
      }
   }
}
