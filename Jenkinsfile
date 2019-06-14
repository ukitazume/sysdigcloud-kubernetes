pipeline {
  agent {
    node { label "${WORKER}" }
  }
  environment {
    registryCredential = 'jenkins-artifactory'
    dockerImage = ''
  }
  stages {
    stage('Build image') {
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
            dockerImage = docker.build("${ARTIFACTORY_URL}/configurator:${env.BUILD_NUMBER}", './configurator/')
          }
        }
      }
    }
    stage('Push image') {
      steps {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
            docker.withRegistry("https://${ARTIFACTORY_URL}", registryCredential) {
              dockerImage.push()
            }
          }
        }
      }
    }
    stage('Cleanup') {
      steps {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          sh "docker rmi ${ARTIFACTORY_URL}/configurator:${env.BUILD_NUMBER}"
        }
      }
    }
  }
}
