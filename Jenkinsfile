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
             
              sh '''
                    for sql_file in *.sql;
            do
                  echo "@${sql_file}" >> output.txt
                  sqlplus -H 103.87.29.229 -E -S . -d QACOP -i "%%G" >> output.txt
            done
                '''
          }
      }
   }
}
