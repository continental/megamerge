/* Copyright (c) 2018 Continental Automotive GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

def megamerge
def deploy

pipeline
{
  agent
  {
    label 'docker'
  }

  options
  {
    buildDiscarder(logRotator(daysToKeepStr: '1'))
    disableConcurrentBuilds()
  }

  stages
  {
    stage('Deploy')
    {
      steps
      {
        script
        {
          if(env.BRANCH_NAME == 'master' || env.BRANCH_NAME == 'staging')
          {
            withCredentials([file(credentialsId: 'megamerge-' + env.BRANCH_NAME, variable: 'FILE')])
            {
              sh('''
                cp $FILE ./src/credentials.yml
                chmod 0644 ./src/credentials.yml
              ''')

              megamerge = docker.build('megamerge')
              megamerge.push(env.BRANCH_NAME)
            }
          }
        }
      }
    }
  }
}
