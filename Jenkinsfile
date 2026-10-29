pipeline {
  agent { label 'kali' }

  options {
    skipDefaultCheckout()
    disableConcurrentBuilds()
  }

  triggers {
    pollSCM('H/2 * * * *')
  }

  stages {
    stage('Checkout') {
      steps {
        echo '[CHECKOUT] Getting source files from GitHub'
        checkout scm
        sh '''
          set -eu
          echo "[CHECKOUT] Commit: $(git rev-parse --short HEAD)"
          ls -l website/
        '''
      }
    }

    stage('Test') {
      steps {
        echo '[TEST] Checking supplied site files and Compose syntax'
        sh 'bash scripts/check.sh'
      }
    }

    stage('Build') {
      steps {
        script {
          def commitId = sh(
            script: 'git rev-parse --short=12 HEAD',
            returnStdout: true
          ).trim()
          env.IMAGE_TAG = "sha-${commitId}-jen-${env.BUILD_NUMBER}"
        }

        echo '[BUILD] Building and HTTP-testing the custom Nginx image'

        withCredentials([
          usernamePassword(
            credentialsId: 'dockerhub-creds',
            usernameVariable: 'HUB_USER',
            passwordVariable: 'DOCKERHUB_TOKEN'
          )
        ]) {
          sh 'bash scripts/build.sh'
        }
      }
    }

    stage('Docker') {
      steps {
        echo '[DOCKER] Publishing image and deploying Nginx + MySQL + phpMyAdmin'

        withCredentials([
          usernamePassword(
            credentialsId: 'dockerhub-creds',
            usernameVariable: 'HUB_USER',
            passwordVariable: 'HUB_TOKEN'
          ),
          string(
            credentialsId: 'mysql-root-password',
            variable: 'MYSQL_ROOT_PASSWORD'
          ),
          string(
            credentialsId: 'mysql-app-password',
            variable: 'MYSQL_PASSWORD'
          )
        ]) {
          sh 'bash scripts/deploy.sh'
        }
      }
    }
  }

  post {
    success {
      echo '[SUCCESS] Jenkins Pipeline completed successfully'
    }
    failure {
      echo '[ERROR] Jenkins Pipeline failed; see Console Output'
    }
  }
}
